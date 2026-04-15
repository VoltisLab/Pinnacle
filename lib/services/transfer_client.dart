import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class TransferClient {
  /// POSTs [filePath] to [baseUrl]/upload (multipart field `file`).
  static Future<int> sendFile(
    String baseUrl,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = _uploadUri(baseUrl);
    final file = File(filePath);
    final length = await file.length();
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: p.basename(filePath),
      ),
    );

    if (onProgress != null) {
      // Approximate: report full size when upload starts (stream progress needs custom tracking).
      onProgress(0, length);
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw TransferException(
        'Upload failed (${streamed.statusCode}): $body',
      );
    }
    if (onProgress != null) {
      onProgress(length, length);
    }
    return streamed.statusCode;
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
