import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Best-effort Wi‑Fi IPv4 for showing the receive URL. May be null on cellular or simulator.
Future<String?> localWifiIPv4() async {
  final info = NetworkInfo();
  try {
    final ip = await info.getWifiIP();
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') return null;
    return ip;
  } catch (_) {
    return null;
  }
}

/// Picks a non-loopback IPv4 for LAN URL / QR (Wi‑Fi first, then any interface).
/// Helps simulators and devices where [localWifiIPv4] is null.
Future<String?> primaryLanIPv4() async {
  final wifi = await localWifiIPv4();
  if (wifi != null) return wifi;

  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: true,
    );
    String? best;
    for (final iface in interfaces) {
      if (iface.name == 'lo0') continue;
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4) continue;
        if (addr.isLoopback) continue;
        final s = addr.address;
        if (s.startsWith('169.254.')) {
          best ??= s;
          continue;
        }
        if (iface.name == 'en0' || iface.name.startsWith('en')) {
          return s;
        }
        best ??= s;
      }
    }
    return best;
  } catch (_) {
    return null;
  }
}

bool get runningOnIosSimulator =>
    Platform.isIOS && Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

/// `true` on platforms where we actually wire a camera-based QR scanner
/// (currently Android + iOS device). On Windows / macOS / Linux and the iOS
/// simulator the user reaches the receiver by pasting the URL or typing the
/// pairing code instead.
bool get supportsCameraQrScan {
  if (runningOnIosSimulator) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Short human label for the current device class, used in copy like
/// "This device (sender)" in the info sheet.
String get deviceKindLabel {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iPhone';
  if (Platform.isMacOS) return 'Mac';
  if (Platform.isWindows) return 'Windows PC';
  if (Platform.isLinux) return 'Linux';
  return 'this device';
}
