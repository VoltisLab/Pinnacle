import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class TransferClient {
  /// POSTs [filePath] to [baseUrl]/upload (multipart field `file`).
  ///
  /// [onProgress] reports [bytesSent], [bytesTotal], and smoothed [speedBytesPerSecond].
  static Future<int> sendFile(
    String baseUrl,
    String filePath, {
    void Function(int bytesSent, int bytesTotal, double speedBytesPerSecond)?
        onProgress,
  }) async {
    final uri = _uploadUri(baseUrl);
    final file = File(filePath);
    final length = await file.length();
    final request = http.MultipartRequest('POST', uri);

    final sw = Stopwatch()..start();
    var sent = 0;
    var lastReportMs = 0;

    Stream<List<int>> metered() async* {
      await for (final chunk in file.openRead()) {
        sent += chunk.length;
        final now = sw.elapsedMilliseconds;
        if (onProgress != null &&
            (now - lastReportMs >= 100 || sent <= 16384)) {
          lastReportMs = now;
          onProgress(sent, length, _bps(sent, sw));
        }
        yield chunk;
      }
      if (onProgress != null) {
        onProgress(sent, length, _bps(sent, sw));
      }
    }

    request.files.add(
      http.MultipartFile(
        'file',
        metered(),
        length,
        filename: p.basename(filePath),
      ),
    );

    if (onProgress != null) {
      onProgress(0, length, 0);
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      // 404 here almost always means the sender is pointed at the wrong host
      // (e.g. a router admin page or DNS-search-suffix mismatch), not that
      // Pinnacle rejected the upload — surface the URL so that's obvious.
      if (streamed.statusCode == 404) {
        throw TransferException(
          'Receiver not found at $uri (HTTP 404). '
          'Make sure Pinnacle is listening on the other device and both are on the same Wi‑Fi. '
          'Try scanning the QR again or restarting the receiver.',
        );
      }
      final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
      throw TransferException(
        'Upload failed (${streamed.statusCode}) at $uri: $snippet',
      );
    }
    if (onProgress != null) {
      onProgress(length, length, _bps(length, sw));
    }
    return streamed.statusCode;
  }

  static double _bps(int bytes, Stopwatch sw) {
    final sec = sw.elapsedMicroseconds / 1000000.0;
    if (sec < 0.0001) return 0;
    return bytes / sec;
  }

  static Uri _uploadUri(String raw) {
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
      path: '/upload',
    );
  }
}

class TransferException implements Exception {
  TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}
