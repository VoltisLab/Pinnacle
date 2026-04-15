import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

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
    final service = BonsoirService(
      name: 'Pinnacle-$code',
      type: pinnacleBonjourType,
      port: port,
      attributes: {
        ...BonsoirService.defaultAttributes,
        'code': code,
      },
    );
    _broadcast = BonsoirBroadcast(service: service);
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
      if (c == want && service.host != null && service.host!.isNotEmpty) {
        final host = service.host!.replaceAll(RegExp(r'\.local\.?$'), '');
        complete('http://$host:${service.port}');
      }
    }
  });

  await discovery.start();
  final result = await completer.future;
  return result;
}
