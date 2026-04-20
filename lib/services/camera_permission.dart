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

/// Ensures we have camera permission on the platforms that need it. On
/// desktop & web the plugin isn't registered and no camera is available,
/// so we short-circuit to [CameraPermissionResult.unsupported].
Future<CameraPermissionResult> ensureCameraPermission() async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return CameraPermissionResult.unsupported;
  }
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
  }
  if (status.isGranted) return CameraPermissionResult.granted;
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
