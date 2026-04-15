/// Human-readable byte rate (e.g. `2.4 MB/s`).
String formatBytesPerSecond(double bytesPerSecond) {
  if (bytesPerSecond <= 0 || bytesPerSecond.isNaN) {
    return '—';
  }
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var v = bytesPerSecond;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  if (i == 0) {
    return '${v.round()} ${units[i]}';
  }
  return '${v.toStringAsFixed(i >= 2 ? 2 : 1)} ${units[i]}';
}
