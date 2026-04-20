import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

import '../models/transfer_ui_state.dart';
import 'shared_storage.dart';

/// Lightweight HTTP server for same-network uploads.
///
/// Endpoints:
///   * `GET /`                 — liveness probe.
///   * `POST /connect`         — sender pair handshake; flips UI to Connected.
///   * `POST /disconnect`      — peer is leaving; flip UI back to Waiting.
///   * `POST /upload-raw`      — fast binary upload (no multipart overhead).
///                               headers: `X-Pinnacle-Filename`,
///                               `Content-Length`, `Content-Type`.
///   * `POST /upload`          — legacy multipart upload (field name `file`).
class TransferServer {
  HttpServer? _httpServer;

  /// Drives receive-side "waiting" vs "connected" vs "receiving" UI.
  final ValueNotifier<ReceiverTransferUi> receiveUi =
      ValueNotifier(const ReceiverWaitingConnection());

  int get port => _httpServer?.port ?? 0;

  bool get isRunning => _httpServer != null;

  /// Whether a sender has completed the `/connect` handshake and not yet
  /// disconnected. Persists across multiple file transfers.
  bool get hasConnectedPeer => _peerLabel != null;

  String? _peerLabel;

  void _emitWaitingConnection() {
    _peerLabel = null;
    receiveUi.value = const ReceiverWaitingConnection();
  }

  void _emitConnected({String? peerLabel}) {
    _peerLabel = peerLabel ?? _peerLabel ?? 'sender';
    receiveUi.value = ReceiverConnected(peerLabel: _peerLabel);
  }

  void _emitReceiving(
    String fileName,
    int received,
    int? total,
    double bps,
  ) {
    receiveUi.value = ReceiverReceiving(
      fileName: fileName,
      bytesReceived: received,
      bytesTotal: total,
      speedBytesPerSecond: bps,
    );
  }

  /// Name of the folder (under Downloads / Documents / etc.) that received
  /// files are published into. Set before [start] or updated between
  /// transfers via settings.
  String saveFolderName = 'Pinnacle';

  /// Scratch directory where in-flight bodies are streamed before being
  /// handed off to [SharedStorage.publishReceivedFile].
  Future<Directory> scratchDirectory() =>
      SharedStorage.scratchReceiveDirectory();

  /// Human-readable label describing where received files end up.
  Future<String> receiveLocationLabel() =>
      SharedStorage.receiveLocationLabel(folder: saveFolderName);

  int? _partContentLength(Multipart part) {
    final raw = part.headers['content-length'];
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  double _bps(int bytes, Stopwatch sw) {
    final sec = sw.elapsedMicroseconds / 1000000.0;
    if (sec < 0.0001) return 0;
    return bytes / sec;
  }

  Future<void> _streamToFile(
    Stream<List<int>> src,
    IOSink out,
    void Function(int received, double bps) tick,
  ) async {
    var received = 0;
    final sw = Stopwatch()..start();
    var lastEmitMs = 0;
    await for (final chunk in src) {
      received += chunk.length;
      out.add(chunk);
      final now = sw.elapsedMilliseconds;
      // Tick ~10 Hz while streaming; also emit an early tick so the UI
      // leaves "connected" quickly once real bytes start flowing.
      if (now - lastEmitMs >= 100 || received <= 65536) {
        lastEmitMs = now;
        tick(received, _bps(received, sw));
      }
    }
    tick(received, _bps(received, sw));
  }

  String _shortPeerLabel(Request request) {
    // shelf stashes the HttpConnectionInfo here when served over shelf_io;
    // treat it opportunistically so we don't hard-depend on a typed import.
    final info = request.context['shelf.io.connection_info'];
    String? remote;
    try {
      remote = (info as dynamic)?.remoteAddress?.address as String?;
    } catch (_) {
      remote = null;
    }
    remote ??= request.headers['x-forwarded-for'];
    if (remote != null && remote.isNotEmpty) {
      final last = remote.split(',').first.trim().split(':').last;
      return 'sender · $last';
    }
    return 'sender';
  }

  Future<void> start() async {
    if (_httpServer != null) return;
    final scratchDir = await scratchDirectory();
    _emitWaitingConnection();

    Future<Response> handleRequest(Request request) async {
      // shelf's `request.url.path` has NO leading slash ("" for root,
      // "upload" for /upload). Tolerate both forms.
      final path = request.url.path;

      if ((path == '' || path == '/') && request.method == 'GET') {
        return Response.ok(
          jsonEncode({'ok': true, 'app': 'Pinnacle', 'apiVersion': 2}),
          headers: {'content-type': 'application/json'},
        );
      }

      // --- Pair handshake: sender has resolved us and is locking the link.
      if ((path == 'connect' || path == '/connect') &&
          request.method == 'POST') {
        final label = _shortPeerLabel(request);
        _emitConnected(peerLabel: label);
        return Response.ok(
          jsonEncode({'ok': true, 'peer': label}),
          headers: {'content-type': 'application/json'},
        );
      }

      // --- Peer is leaving; flip UI back to waiting for a new connection.
      if ((path == 'disconnect' || path == '/disconnect') &&
          request.method == 'POST') {
        _emitWaitingConnection();
        return Response.ok(
          jsonEncode({'ok': true}),
          headers: {'content-type': 'application/json'},
        );
      }

      // --- Fast path: raw binary upload. No multipart framing.
      if ((path == 'upload-raw' || path == '/upload-raw') &&
          request.method == 'POST') {
        final encodedName = request.headers['x-pinnacle-filename'];
        if (encodedName == null || encodedName.isEmpty) {
          return Response.badRequest(body: 'Missing X-Pinnacle-Filename');
        }
        final name = _safeFileName(_decode(encodedName));
        final totalHdr = request.headers['content-length'];
        final total = (totalHdr == null) ? null : int.tryParse(totalHdr);
        final scratch = await _uniqueFile(scratchDir, name);
        final mime = (request.headers['content-type'] ?? '')
                .split(';')
                .first
                .trim()
                .isEmpty
            ? 'application/octet-stream'
            : request.headers['content-type']!.split(';').first.trim();

        final out = scratch.openWrite();
        try {
          await _streamToFile(
            request.read(),
            out,
            (received, bps) => _emitReceiving(name, received, total, bps),
          );
        } finally {
          await out.flush();
          await out.close();
        }

        try {
          await SharedStorage.publishReceivedFile(
            sourcePath: scratch.path,
            displayName: name,
            mimeType: mime,
            folder: saveFolderName,
          );
        } catch (e, st) {
          debugPrint('Pinnacle publish error: $e\n$st');
        }
        // Return to "connected" so the receiver shows the tick + waiting
        // animation, ready for the next file.
        _emitConnected();
        return Response.ok(
          jsonEncode({'ok': true, 'saved': 1}),
          headers: {'content-type': 'application/json'},
        );
      }

      // --- Legacy multipart upload for backward compat / manual testing.
      if ((path == 'upload' || path == '/upload') &&
          request.method == 'POST') {
        final form = request.formData();
        if (form == null) {
          return Response.badRequest(body: 'Expected multipart form-data');
        }
        try {
          var saved = 0;
          await for (final formData in form.formData) {
            if (formData.name != 'file') continue;
            final name = _safeFileName(formData.filename ?? 'file');
            final scratch = await _uniqueFile(scratchDir, name);
            final total = _partContentLength(formData.part);
            final mime = formData.part.headers['content-type']
                    ?.split(';')
                    .first
                    .trim() ??
                'application/octet-stream';

            final out = scratch.openWrite();
            try {
              await _streamToFile(
                formData.part,
                out,
                (received, bps) => _emitReceiving(name, received, total, bps),
              );
            } finally {
              await out.flush();
              await out.close();
            }
            try {
              await SharedStorage.publishReceivedFile(
                sourcePath: scratch.path,
                displayName: name,
                mimeType: mime,
                folder: saveFolderName,
              );
            } catch (e, st) {
              debugPrint('Pinnacle publish error: $e\n$st');
            }
            saved++;
          }
          if (saved == 0) {
            _emitConnected();
            return Response.badRequest(body: 'No file field named "file"');
          }
          _emitConnected();
          return Response.ok(jsonEncode({'ok': true, 'saved': saved}),
              headers: {'content-type': 'application/json'});
        } catch (e, st) {
          debugPrint('Pinnacle upload error: $e\n$st');
          _emitConnected();
          return Response.internalServerError(body: 'Upload failed: $e');
        }
      }

      return Response.notFound('Not found');
    }

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware)
        .addHandler(handleRequest);

    _httpServer = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      0,
    );
    _emitWaitingConnection();
  }

  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    if (server != null) {
      await server.close(force: true);
    }
    _emitWaitingConnection();
  }

  void dispose() {
    receiveUi.dispose();
  }
}

String _decode(String raw) {
  try {
    return Uri.decodeComponent(raw);
  } catch (_) {
    return raw;
  }
}

String _safeFileName(String name) {
  final base = p.basename(name.replaceAll('\\', '/'));
  if (base.isEmpty) return 'file';
  return base.replaceAll(RegExp(r'[^\w.\- ]+'), '_');
}

Future<File> _uniqueFile(Directory dir, String name) async {
  var target = File(p.join(dir.path, name));
  if (!await target.exists()) return target;
  final stem = p.basenameWithoutExtension(name);
  final ext = p.extension(name);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  target = File(p.join(dir.path, '${stem}_$stamp$ext'));
  return target;
}

Middleware get _corsMiddleware => (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };
    };

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Pinnacle-Filename',
};
