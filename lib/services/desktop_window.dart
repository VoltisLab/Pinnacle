import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

/// True on non-web desktop (Windows / macOS / Linux). Used to gate every
/// call to [WindowManager] so mobile builds don't hit a null plugin.
bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Applies our fixed-square desktop window policy:
///   * 720 × 720 (slightly taller than wide feels cramped; square is
///     what the user asked for and matches the app's content density).
///   * Non-resizable (min == max == size) so the UI never has to worry
///     about extreme aspect ratios.
///   * Centered on the primary screen at first launch.
///
/// Safe to call from any entrypoint; no-op on mobile / web.
Future<void> applyDesktopWindowPolicy({
  bool alwaysOnTop = false,
}) async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  const size = Size(720, 720);
  final opts = WindowOptions(
    size: size,
    minimumSize: size,
    maximumSize: size,
    center: true,
    title: 'Pinnacle',
    alwaysOnTop: alwaysOnTop,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);
    if (alwaysOnTop) {
      await windowManager.setAlwaysOnTop(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Toggle "stay on top" at runtime. No-op on mobile / web.
Future<void> setAlwaysOnTop(bool value) async {
  if (!isDesktop) return;
  try {
    await windowManager.setAlwaysOnTop(value);
  } catch (_) {
    // Some Linux WMs don't honour this — silently ignore.
  }
}
