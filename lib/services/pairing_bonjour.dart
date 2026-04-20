import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'local_address.dart';

/// Bonjour type for Pinnacle receive sessions (TXT includes `code`).
const String pinnacleBonjourType = '_pinnacle._tcp';

/// Advertises this device as a receiver (port + pairing code in TXT).
class PairingBonjourAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({
    required int port,
    required String pairCode,
  }) async {
    await stop();
    final code = pairCode.trim().toUpperCase();
    // Include our LAN IPv4 in the TXT record so senders can connect by IP
    // (more reliable than relying on the bonjour hostname, which on Android
    // often doesn't resolve because the OS has no mDNS resolver for raw
    // sockets and may route bare names through a DNS search-suffix to a
    // completely different HTTP server — yielding confusing 404s).
    final ip = await primaryLanIPv4();
    _broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: 'Pinnacle-$code',
        type: pinnacleBonjourType,
        port: port,
        attributes: {
          ...BonsoirService.defaultAttributes,
          'code': code,
          if (ip != null) 'ip': ip,
        },
      ),
    );
    await _broadcast!.initialize();
    await _broadcast!.start();
  }

  Future<void> stop() async {
    final b = _broadcast;
    _broadcast = null;
    if (b != null) {
      await b.stop();
    }
  }
}

/// Finds receiver `http://host:port` by pairing [code] on the local network.
Future<String?> resolveHttpBaseUrlByPairingCode(
  String pairCode, {
  Duration timeout = const Duration(seconds: 18),
}) async {
  final want = pairCode.trim().toUpperCase();
  if (want.isEmpty) return null;

  final discovery = BonsoirDiscovery(type: pinnacleBonjourType);
  await discovery.initialize();

  final completer = Completer<String?>();
  Timer? timer;
  StreamSubscription<BonsoirDiscoveryEvent>? sub;

  void complete(String? url) {
    if (!completer.isCompleted) completer.complete(url);
    timer?.cancel();
    sub?.cancel();
    unawaited(discovery.stop());
  }

  timer = Timer(timeout, () => complete(null));

  sub = discovery.eventStream?.listen((event) async {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      try {
        await discovery.serviceResolver.resolveService(event.service);
      } catch (_) {}
    } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final service = event.service;
      final c = service.attributes['code']?.trim().toUpperCase();
      if (c != want) return;
      // Prefer the explicit LAN IP from the TXT record — raw IPs are
      // resolvable everywhere. Fall back to the bonjour hostname as-is
      // (keeping any `.local` suffix so mDNS resolution still works on
      // platforms that support it).
      final ipAttr = service.attributes['ip']?.trim();
      if (ipAttr != null && ipAttr.isNotEmpty) {
        complete('http://$ipAttr:${service.port}');
        return;
      }
      final host = service.host?.trim();
      if (host != null && host.isNotEmpty) {
        complete('http://$host:${service.port}');
      }
    }
  });

  await discovery.start();
  final result = await completer.future;
  return result;
}
