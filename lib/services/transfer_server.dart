import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';

/// Lightweight HTTP server for same-network uploads (multipart field name: `file`).
class TransferServer {
  HttpServer? _httpServer;

  int get port => _httpServer?.port ?? 0;

  bool get isRunning => _httpServer != null;

  Future<Directory> receiveDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'Pinnacle', 'Received'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> start() async {
    if (_httpServer != null) return;
    final receiveDir = await receiveDirectory();

    Future<Response> handleRequest(Request request) async {
      if (request.url.path == '/' && request.method == 'GET') {
        return Response.ok(
          '{"ok":true,"app":"Pinnacle"}',
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/upload' && request.method == 'POST') {
        final form = request.formData();
        if (form != null) {
          var saved = 0;
          await for (final formData in form.formData) {
            if (formData.name != 'file') continue;
            final name = _safeFileName(formData.filename ?? 'file');
            final target = await _uniqueFile(receiveDir, name);
            final bytes = await formData.part.readBytes();
            await target.writeAsBytes(bytes, flush: true);
            saved++;
          }
          if (saved == 0) {
            return Response.badRequest(body: 'No file field named "file"');
          }
          return Response.ok('{"ok":true,"saved":$saved}',
              headers: {'content-type': 'application/json'});
        }
        return Response.badRequest(body: 'Expected multipart form-data');
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
  }

  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    if (server != null) {
      await server.close(force: true);
    }
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
