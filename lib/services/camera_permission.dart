import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// Outcome of asking for camera access. `unsupported` is returned on
/// platforms where we don't wire a camera-based QR scanner (Windows /
/// macOS / Linux / web / iOS simulator), so callers can degrade the UI
/// gracefully instead of treating it as a denial.
enum CameraPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  unsupported,
}

/// Ensures we have camera permission on the platforms that need it.
///
/// On iOS in particular, [Permission.camera.status] is frequently stale:
/// if the user previously denied and then re-enabled camera access in
/// Settings, `.status` can keep returning `permanentlyDenied` until a
/// `.request()` call refreshes it. So we always call `.request()` (which
/// is a no-op that just returns `granted` when access is already allowed)
/// and trust that result — no more "already enabled? then why is it
/// telling me to open Settings?" bugs.
Future<CameraPermissionResult> ensureCameraPermission() async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return CameraPermissionResult.unsupported;
  }
  final status = await Permission.camera.request();
  if (status.isGranted || status.isLimited) {
    return CameraPermissionResult.granted;
  }
  if (status.isPermanentlyDenied) {
    return CameraPermissionResult.permanentlyDenied;
  }
  return CameraPermissionResult.denied;
}

/// Opens the OS app-settings screen so the user can flip camera back on
/// after a permanent denial. No-op on desktop & web.
Future<void> openCameraSettings() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  await openAppSettings();
}
