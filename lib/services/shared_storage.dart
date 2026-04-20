import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a fully-received file ended up after publishing and a friendly,
/// user-facing label to surface that location in the UI.
class PublishedFile {
  const PublishedFile({
    required this.displayLabel,
    required this.directoryLabel,
    this.uri,
    this.filePath,
  });

  /// e.g. "Downloads / Pinnacle / holiday.jpg".
  final String displayLabel;

  /// e.g. "Downloads / Pinnacle" — the directory portion, for "save to" hints.
  final String directoryLabel;

  /// Content / file URI on Android (`content://…` on API 29+, `file://…`
  /// otherwise); `file://…` on iOS / desktop. May be `null` if only a path
  /// is known.
  final String? uri;

  /// Absolute file path when available (nil on Android MediaStore publishes).
  final String? filePath;
}

/// Hands received files off to the OS's real, user-visible storage so they
/// show up where people expect — Downloads on Android, the Files app on iOS,
/// ~/Downloads on desktop.
class SharedStorage {
  static const MethodChannel _channel =
      MethodChannel('com.pinnacle.transfer/storage');

  /// Returns a scratch directory that receive code can write the incoming
  /// multipart stream into before calling [publishReceivedFile]. Using the
  /// app cache directory avoids polluting the user's Documents with
  /// half-written files if a transfer is interrupted mid-flight.
  static Future<Directory> scratchReceiveDirectory() async {
    final root = await getTemporaryDirectory();
    final dir = Directory(p.join(root.path, 'Pinnacle', 'incoming'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Human-readable label describing WHERE received files are saved. The
  /// receive screen shows this so users know to look in their Downloads /
  /// Files app / `~/Downloads`.
  static Future<String> receiveLocationLabel() async {
    if (Platform.isAndroid) return 'Downloads / Pinnacle';
    if (Platform.isIOS) {
      return 'Files app → On My iPhone → Pinnacle → Received';
    }
    final downloads = await getDownloadsDirectory();
    final base = downloads ?? await getApplicationDocumentsDirectory();
    return p.join(base.path, 'Pinnacle');
  }

  /// Moves [sourcePath] — normally a fully-written file in the scratch
  /// directory — into the platform's user-visible storage, returning a
  /// [PublishedFile] describing the final location.
  ///
  /// The source file is removed on success (or replaced by the rename on
  /// iOS / desktop); if publishing fails the caller can fall back to the
  /// scratch path so the bytes aren't lost.
  static Future<PublishedFile> publishReceivedFile({
    required String sourcePath,
    required String displayName,
    String mimeType = 'application/octet-stream',
  }) async {
    if (Platform.isAndroid) {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'publishToDownloads',
        {
          'sourcePath': sourcePath,
          'displayName': displayName,
          'mime': mimeType,
        },
      );
      if (raw == null) {
        throw const _PublishError('Native channel returned no data');
      }
      return PublishedFile(
        uri: raw['uri'] as String?,
        displayLabel:
            raw['displayLabel'] as String? ?? 'Downloads / Pinnacle / $displayName',
        directoryLabel:
            raw['directoryLabel'] as String? ?? 'Downloads / Pinnacle',
      );
    }

    if (Platform.isIOS) {
      return _publishIntoDocuments(
        sourcePath: sourcePath,
        displayName: displayName,
        directoryLabel: 'Files → On My iPhone → Pinnacle → Received',
      );
    }

    return _publishIntoDesktopDownloads(
      sourcePath: sourcePath,
      displayName: displayName,
    );
  }

  static Future<PublishedFile> _publishIntoDocuments({
    required String sourcePath,
    required String displayName,
    required String directoryLabel,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Pinnacle', 'Received'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = await _uniqueFile(dir, displayName);
    await _moveOrCopy(File(sourcePath), target);
    return PublishedFile(
      uri: target.uri.toString(),
      filePath: target.path,
      displayLabel: '$directoryLabel / ${p.basename(target.path)}',
      directoryLabel: directoryLabel,
    );
  }

  static Future<PublishedFile> _publishIntoDesktopDownloads({
    required String sourcePath,
    required String displayName,
  }) async {
    final downloadsDir = await getDownloadsDirectory();
    final base = downloadsDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'Pinnacle'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = await _uniqueFile(dir, displayName);
    await _moveOrCopy(File(sourcePath), target);
    return PublishedFile(
      uri: target.uri.toString(),
      filePath: target.path,
      displayLabel: target.path,
      directoryLabel: dir.path,
    );
  }

  static Future<void> _moveOrCopy(File source, File target) async {
    try {
      await source.rename(target.path);
      return;
    } on FileSystemException {
      // Cross-device rename (e.g. tmp on a different volume than Documents);
      // fall back to copy-then-delete.
      await source.copy(target.path);
      try {
        await source.delete();
      } catch (_) {}
    }
  }

  static Future<File> _uniqueFile(Directory dir, String name) async {
    var target = File(p.join(dir.path, name));
    if (!await target.exists()) return target;
    final stem = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return File(p.join(dir.path, '${stem}_$stamp$ext'));
  }
}

class _PublishError implements Exception {
  const _PublishError(this.message);
  final String message;
  @override
  String toString() => 'SharedStorage: $message';
}
