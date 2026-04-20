import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class TransferClient {
  /// Calls `POST /connect` on the receiver to confirm the pair handshake.
  /// Returns a short peer label supplied by the receiver on success.
  /// Throws [TransferException] on network errors or non-2xx responses.
  static Future<String> connect(String baseUrl) async {
    final uri = _endpointUri(baseUrl, '/connect');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.postUrl(uri);
      req.headers.contentLength = 0;
      req.headers.contentType = ContentType.json;
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw TransferException(
          'Connect failed (${resp.statusCode}) at $uri.',
        );
      }
      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        return (j['peer'] as String?) ?? 'receiver';
      } catch (_) {
        return 'receiver';
      }
    } on SocketException catch (e) {
      throw TransferException('Could not reach the receiver: ${e.message}');
    } on TimeoutException {
      throw TransferException(
        'The receiver didn\'t respond in time. Is it still listening on the same Wi‑Fi?',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Best-effort `POST /disconnect`. Failures are swallowed — the sender's
  /// UI should still reset locally even if the receiver has gone away.
  static Future<void> disconnect(String baseUrl) async {
    final uri = _endpointUri(baseUrl, '/disconnect');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.postUrl(uri);
      req.headers.contentLength = 0;
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
    } catch (_) {
      // Disconnect is advisory — ignore.
    } finally {
      client.close(force: true);
    }
  }

  /// Streams [filePath] to the receiver's fast raw endpoint.
  ///
  /// [onProgress] reports bytes sent / total and smoothed bytes/sec. Uses
  /// `POST /upload-raw` with:
  ///   * `Content-Length`         — file size
  ///   * `Content-Type`           — `application/octet-stream`
  ///   * `X-Pinnacle-Filename`    — URI-encoded original basename
  ///
  /// Dramatically faster than multipart because there's no boundary
  /// framing overhead and each chunk goes straight to the socket.
  static Future<int> sendFile(
    String baseUrl,
    String filePath, {
    void Function(int bytesSent, int bytesTotal, double speedBytesPerSecond)?
        onProgress,
  }) async {
    final uri = _endpointUri(baseUrl, '/upload-raw');
    final file = File(filePath);
    final length = await file.length();
    final name = p.basename(filePath);

    final sw = Stopwatch()..start();
    var sent = 0;
    var lastReportMs = 0;

    // [file.openRead] hands us 64 KB-ish chunks already; just forward
    // them straight to the socket. The speed wins come from (a) dropping
    // multipart framing, (b) `bufferOutput = false`, and (c) setting an
    // explicit `Content-Length` so the HttpClient doesn't fall back to
    // chunked transfer-encoding, which halves LAN throughput in practice.
    Stream<List<int>> metered() async* {
      await for (final chunk in file.openRead()) {
        sent += chunk.length;
        if (onProgress != null) {
          final now = sw.elapsedMilliseconds;
          if (now - lastReportMs >= 100 || sent <= 65536) {
            lastReportMs = now;
            onProgress(sent, length, _bps(sent, sw));
          }
        }
        yield chunk;
      }
      if (onProgress != null) {
        onProgress(sent, length, _bps(sent, sw));
      }
    }

    if (onProgress != null) onProgress(0, length, 0);

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'octet-stream');
      req.headers.contentLength = length;
      req.headers.set(
        'X-Pinnacle-Filename',
        Uri.encodeComponent(name),
      );
      req.bufferOutput = false;
      await req.addStream(metered());
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        if (resp.statusCode == 404) {
          // Receiver is a Pinnacle we can't speak raw to — the remote
          // app may be older than v2. Fall back to multipart.
          return _sendMultipart(
            baseUrl,
            filePath,
            onProgress: onProgress,
          );
        }
        final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
        throw TransferException(
          'Upload failed (${resp.statusCode}) at $uri: $snippet',
        );
      }
      if (onProgress != null) onProgress(length, length, _bps(length, sw));
      return resp.statusCode;
    } on SocketException catch (e) {
      throw TransferException('Connection lost: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// Multipart fallback (old servers). Retains the previous wire format.
  static Future<int> _sendMultipart(
    String baseUrl,
    String filePath, {
    void Function(int, int, double)? onProgress,
  }) async {
    final uri = _endpointUri(baseUrl, '/upload');
    final file = File(filePath);
    final length = await file.length();
    final name = p.basename(filePath);
    final boundary =
        '----PinnacleBoundary${DateTime.now().microsecondsSinceEpoch}';
    final header = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="$name"\r\n'
      'Content-Type: application/octet-stream\r\n'
      'Content-Length: $length\r\n\r\n',
    );
    final footer = utf8.encode('\r\n--$boundary--\r\n');
    final totalLen = header.length + length + footer.length;

    final sw = Stopwatch()..start();
    var sent = 0;
    var lastMs = 0;

    Stream<List<int>> body() async* {
      yield header;
      await for (final chunk in file.openRead()) {
        sent += chunk.length;
        if (onProgress != null) {
          final now = sw.elapsedMilliseconds;
          if (now - lastMs >= 100 || sent <= 65536) {
            lastMs = now;
            onProgress(sent, length, _bps(sent, sw));
          }
        }
        yield chunk;
      }
      yield footer;
    }

    if (onProgress != null) onProgress(0, length, 0);

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType =
          ContentType('multipart', 'form-data', parameters: {'boundary': boundary});
      req.headers.contentLength = totalLen;
      req.bufferOutput = false;
      await req.addStream(body());
      final resp = await req.close();
      final bodyStr = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw TransferException(
          'Upload failed (${resp.statusCode}) at $uri: $bodyStr',
        );
      }
      if (onProgress != null) onProgress(length, length, _bps(length, sw));
      return resp.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  static double _bps(int bytes, Stopwatch sw) {
    final sec = sw.elapsedMicroseconds / 1000000.0;
    if (sec < 0.0001) return 0;
    return bytes / sec;
  }

  static Uri _endpointUri(String raw, String path) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw TransferException('Enter a receive address or scan a QR code.');
    }
    if (!trimmed.contains('://')) {
      trimmed = 'http://$trimmed';
    }
    final base = Uri.parse(trimmed);
    if (!base.hasAuthority) {
      throw TransferException('Invalid address.');
    }
    return Uri(
      scheme: base.scheme.isEmpty ? 'http' : base.scheme,
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    );
  }
}

class TransferException implements Exception {
  TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}
