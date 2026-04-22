import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import 'shared_storage.dart';

/// Opens the OS file manager / viewer at the folder that contains a received
/// file. Behaviour is platform-specific but aims for one tap from the
/// Receive screen after a successful save.
class ReceiveLocationOpener {
  ReceiveLocationOpener._();

  static const MethodChannel _channel =
      MethodChannel('com.pinnacle.transfer/storage');

  /// Best-effort folder open. Throws only when every path fails (caller
  /// may show a SnackBar).
  static Future<void> openFromPublished(PublishedFile file) async {
    // Real filesystem path (iOS app sandbox, legacy Android file://, desktop).
    if (file.filePath != null && file.filePath!.isNotEmpty) {
      final dir = p.dirname(file.filePath!);
      final r = await OpenFile.open(dir);
      if (r.type == ResultType.done) return;
      if (r.type == ResultType.noAppToOpen) {
        throw Exception('No app can open this location.');
      }
      if (r.message.isNotEmpty) {
        throw Exception(r.message);
      }
      return;
    }

    final uri = file.uri;
    if (uri != null && uri.startsWith('file:')) {
      final path = Uri.parse(uri).toFilePath();
      final dir = p.dirname(path);
      final r = await OpenFile.open(dir);
      if (r.type == ResultType.done) return;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final label = file.directoryLabel;
      if (label.isNotEmpty &&
          (p.isAbsolute(label) ||
              (Platform.isWindows && label.contains(':')))) {
        final r = await OpenFile.open(label);
        if (r.type == ResultType.done) return;
        if (r.message.isNotEmpty) {
          throw Exception(r.message);
        }
      }
    }

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('openReceivedLocation', {
          'uri': file.uri,
          'mime': 'application/octet-stream',
          'folder': _folderFromDirectoryLabel(file.directoryLabel),
        });
        return;
      } on PlatformException catch (e) {
        if (kDebugMode) {
          debugPrint('openReceivedLocation: ${e.message}');
        }
        throw Exception(e.message ?? 'Could not open Downloads');
      }
    }

    throw Exception('Could not open this location on this device.');
  }

  static String _folderFromDirectoryLabel(String label) {
    final parts = label
        .split(RegExp(r'[/\\]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Pinnacle';
    return parts.last;
  }
}
