import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

import '../models/transfer_ui_state.dart';

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

  Future<Directory> receiveDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'Pinnacle', 'Received'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

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
    final receiveDir = await receiveDirectory();
    _emitWaiting();

    Future<Response> handleRequest(Request request) async {
      if (request.url.path == '/' && request.method == 'GET') {
        return Response.ok(
          '{"ok":true,"app":"Pinnacle"}',
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/upload' && request.method == 'POST') {
        final form = request.formData();
        if (form == null) {
          return Response.badRequest(body: 'Expected multipart form-data');
        }
        try {
          var saved = 0;
          await for (final formData in form.formData) {
            if (formData.name != 'file') continue;
            final name = _safeFileName(formData.filename ?? 'file');
            final target = await _uniqueFile(receiveDir, name);
            final total = _partContentLength(formData.part);
            _emitReceiving(name, 0, total, 0);
            final out = target.openWrite();
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
