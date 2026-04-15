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
      throw TransferException(
        'Upload failed (${streamed.statusCode}): $body',
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
    return base.replace(
      path: '/upload',
      query: '',
      fragment: '',
    );
  }
}

class TransferException implements Exception {
  TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}
