/// Deep link payload when we cannot show a plain `http://` URL (no LAN IP yet).
/// Send screen resolves this via Bonjour using [code].
const String pinnacleScheme = 'pinnacle';

String buildPinnacleReceiveUri({required int port, required String pairCode}) {
  final c = Uri.encodeComponent(pairCode.trim().toUpperCase());
  return 'pinnacle://receive?port=$port&code=$c';
}

/// Returns `http://host:port` if [raw] is HTTP/S; `null` if needs Bonjour resolution.
String? httpBaseUrlFromPayload(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (!t.contains('://')) {
    return httpBaseUrlFromPayload('http://$t');
  }
  final u = Uri.tryParse(t);
  if (u == null) return null;
  if (u.scheme == 'http' || u.scheme == 'https') {
    if (!u.hasAuthority) return null;
    return u.replace(path: '', query: '', fragment: '').toString().replaceAll(RegExp(r'/$'), '');
  }
  return null;
}

({int port, String code})? parsePinnacleReceiveUri(String raw) {
  final u = Uri.tryParse(raw.trim());
  if (u == null || u.scheme != pinnacleScheme) return null;
  if (u.host != 'receive') return null;
  final port = int.tryParse(u.queryParameters['port'] ?? '');
  final code = u.queryParameters['code'];
  if (port == null || port <= 0 || code == null || code.isEmpty) return null;
  return (port: port, code: code);
}
