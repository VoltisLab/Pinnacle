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
