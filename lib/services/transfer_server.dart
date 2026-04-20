import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

import '../models/transfer_ui_state.dart';
import 'shared_storage.dart';

/// Lightweight HTTP server for same-network uploads (multipart field name: `file`).
class TransferServer {
  HttpServer? _httpServer;

  /// Drives receive-side “waiting” vs “receiving + % / speed” UI.
  final ValueNotifier<ReceiverTransferUi> receiveUi =
      ValueNotifier(const ReceiverWaiting());

  int get port => _httpServer?.port ?? 0;

  bool get isRunning => _httpServer != null;

  void _emitWaiting() {
    receiveUi.value = const ReceiverWaiting();
  }

  void _emitConnected(String fileName) {
    receiveUi.value = ReceiverConnected(fileName: fileName);
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

  /// Scratch directory where in-flight multipart bodies are streamed before
  /// being handed off to [SharedStorage.publishReceivedFile]. Callers
  /// shouldn't surface this to users — use [receiveLocationLabel] instead.
  Future<Directory> scratchDirectory() => SharedStorage.scratchReceiveDirectory();

  /// Human-readable label describing where received files end up (e.g.
  /// "Downloads / Pinnacle" on Android). Use this in the receive UI.
  Future<String> receiveLocationLabel() =>
      SharedStorage.receiveLocationLabel(folder: saveFolderName);

  int? _partContentLength(Multipart part) {
    final raw = part.headers['content-length'];
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _streamPartToFile(
    Multipart part,
    IOSink out,
    void Function(int received, double bps) tick,
  ) async {
    var received = 0;
    final sw = Stopwatch()..start();
    var lastEmitMs = 0;
    await for (final chunk in part) {
      received += chunk.length;
      out.add(chunk);
      final now = sw.elapsedMilliseconds;
      if (now - lastEmitMs >= 100 || received <= 16384) {
        lastEmitMs = now;
        tick(received, _bps(received, sw));
      }
    }
    tick(received, _bps(received, sw));
  }

  double _bps(int bytes, Stopwatch sw) {
    final sec = sw.elapsedMicroseconds / 1000000.0;
    if (sec < 0.0001) return 0;
    return bytes / sec;
  }

  Future<void> start() async {
    if (_httpServer != null) return;
    final scratchDir = await scratchDirectory();
    _emitWaiting();

    Future<Response> handleRequest(Request request) async {
      // Note: shelf's `request.url` is relative, so `url.path` has NO leading
      // slash ("" for root, "upload" for /upload). Comparing against "/upload"
      // always fails and every request would fall through to 404.
      final path = request.url.path;

      if ((path == '' || path == '/') && request.method == 'GET') {
        return Response.ok(
          '{"ok":true,"app":"Pinnacle"}',
          headers: {'content-type': 'application/json'},
        );
      }

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
            // Flash "Connected" for a beat before bytes start flowing so the
            // receiver clearly registers that the sender has linked up, then
            // let the first chunk's tick transition us into "Receiving".
            _emitConnected(name);
            await Future<void>.delayed(const Duration(milliseconds: 700));
            final out = scratch.openWrite();
            try {
              await _streamPartToFile(
                formData.part,
                out,
                (received, bps) => _emitReceiving(name, received, total, bps),
              );
            } finally {
              await out.flush();
              await out.close();
            }
            // Hand the completed file off to the user-visible location.
            // If publishing fails we still have the scratch copy — leave it
            // on disk so data isn't lost, but report the failure.
            try {
              await SharedStorage.publishReceivedFile(
                sourcePath: scratch.path,
                displayName: name,
                mimeType: mime,
                folder: saveFolderName,
              );
            } catch (e, st) {
              debugPrint('Pinnacle publish error: $e\n$st');
              // Fall through with success: the bytes are safe in scratch and
              // the sender shouldn't see a 500 for an OS-level failure.
            }
            saved++;
          }
          if (saved == 0) {
            _emitWaiting();
            return Response.badRequest(body: 'No file field named "file"');
          }
          _emitWaiting();
          return Response.ok('{"ok":true,"saved":$saved}',
              headers: {'content-type': 'application/json'});
        } catch (e, st) {
          debugPrint('Pinnacle upload error: $e\n$st');
          _emitWaiting();
          return Response.internalServerError(body: 'Upload failed: $e');
        }
      }

      return Response.notFound('Not found');
    }

    final handler =
        Pipeline().addMiddleware(_corsMiddleware).addHandler(handleRequest);

    _httpServer = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      0,
    );
    _emitWaiting();
  }

  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    if (server != null) {
      await server.close(force: true);
    }
    _emitWaiting();
  }

  void dispose() {
    receiveUi.dispose();
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
  'Access-Control-Allow-Headers': 'Content-Type',
};
