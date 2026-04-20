import 'package:flutter/foundation.dart';

/// Role of the current transfer from the user's perspective.
enum TransferRole { sending, receiving }

/// Snapshot of the active transfer, published to the global overlay.
@immutable
class TransferSnapshot {
  const TransferSnapshot({
    required this.role,
    required this.fileName,
    required this.bytesDone,
    required this.bytesTotal,
    required this.bytesPerSecond,
  });

  final TransferRole role;
  final String fileName;
  final int bytesDone;
  final int bytesTotal;
  final double bytesPerSecond;

  double get fraction =>
      bytesTotal > 0 ? (bytesDone / bytesTotal).clamp(0.0, 1.0) : 0.0;

  int get percent => (fraction * 100).round().clamp(0, 100);
}

/// App-wide publisher for the single active transfer. The [TransferOverlay]
/// widget listens and renders a floating card above everything when the
/// value is non-null.
class TransferOverlayController extends ValueNotifier<TransferSnapshot?> {
  TransferOverlayController() : super(null);

  static final instance = TransferOverlayController();

  void publish(TransferSnapshot snapshot) => value = snapshot;

  void clear() => value = null;
}
