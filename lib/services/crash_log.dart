import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Best-effort per-install crash log. On desktop it lives next to the EXE's
/// writable support dir so a user (or we) can grab it after a hang / close
/// without needing a dev build. Silently no-ops if the filesystem is
/// unavailable (mobile sandboxing edge cases, read-only mounts, etc.).
class CrashLog {
  static File? _file;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      Directory base;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        base = await getApplicationSupportDirectory();
      } else {
        base = await getApplicationDocumentsDirectory();
      }
      final dir = Directory(p.join(base.path, 'logs'));
      if (!await dir.exists()) await dir.create(recursive: true);
      _file = File(p.join(dir.path, 'crash.log'));
      await _appendLine(
        '=== Pinnacle session started '
        '${DateTime.now().toIso8601String()} '
        'on ${Platform.operatingSystem} ${Platform.operatingSystemVersion} ===',
      );
    } catch (_) {
      _file = null;
    }
  }

  /// Public human-readable path (for "Open crash log" affordances). Null
  /// until [init] succeeds.
  static String? get filePath => _file?.path;

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? label,
  }) async {
    debugPrint('Pinnacle crash${label != null ? ' [$label]' : ''}: $error');
    if (stack != null) debugPrint(stack.toString());
    await _appendLine(
      '--- ${DateTime.now().toIso8601String()}'
      '${label != null ? ' [$label]' : ''} ---\n'
      '$error\n${stack ?? ''}',
    );
  }

  static Future<void> _appendLine(String text) async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString('$text\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}

/// Wraps the app entrypoint in a zone that captures every uncaught Dart
/// error (including unawaited Futures) so we don't rely on the platform
/// to surface them. Pair with [FlutterError.onError] / [PlatformDispatcher.
/// instance.onError] for full coverage.
Future<void> runGuardedApp(Future<void> Function() run) async {
  await CrashLog.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLog.recordError(
      details.exception,
      details.stack,
      label: 'FlutterError',
    );
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashLog.recordError(error, stack, label: 'PlatformDispatcher');
      return true;
    };
    await run();
  }, (error, stack) {
    CrashLog.recordError(error, stack, label: 'ZoneGuard');
  });
}
