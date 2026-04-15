/// Receiver-side UI driven by [TransferServer.receiveUi].
sealed class ReceiverTransferUi {
  const ReceiverTransferUi();
}

/// Server on, no active upload body being read.
final class ReceiverWaiting extends ReceiverTransferUi {
  const ReceiverWaiting() : super();
}

/// Streaming a file from the sender.
final class ReceiverReceiving extends ReceiverTransferUi {
  const ReceiverReceiving({
    required this.fileName,
    required this.bytesReceived,
    required this.bytesTotal,
    required this.speedBytesPerSecond,
  }) : super();

  final String fileName;
  final int bytesReceived;
  final int? bytesTotal;
  final double speedBytesPerSecond;

  double get fraction {
    final t = bytesTotal;
    if (t == null || t <= 0) return 0;
    return (bytesReceived / t).clamp(0.0, 1.0);
  }

  int get percent => (fraction * 100).round().clamp(0, 100);
}

/// Sender-side upload progress (one file at a time).
class SenderUploadProgress {
  const SenderUploadProgress({
    required this.fileName,
    required this.bytesSent,
    required this.bytesTotal,
    required this.speedBytesPerSecond,
  });

  final String fileName;
  final int bytesSent;
  final int bytesTotal;
  final double speedBytesPerSecond;

  double get fraction =>
      bytesTotal > 0 ? (bytesSent / bytesTotal).clamp(0.0, 1.0) : 0.0;

  int get percent => (fraction * 100).round().clamp(0, 100);
}
