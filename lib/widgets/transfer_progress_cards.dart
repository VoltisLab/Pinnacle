import 'package:flutter/material.dart';

import '../models/transfer_ui_state.dart';
import 'transfer_format.dart';

/// Sender: upload progress (percent + speed).
class SenderUploadBanner extends StatelessWidget {
  const SenderUploadBanner({super.key, required this.progress});

  final SenderUploadProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = progress.bytesTotal > 0 ? progress.percent : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sending',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.bytesTotal > 0 ? progress.fraction : null,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  progress.bytesTotal > 0 ? '$pct%' : '…',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  formatBytesPerSecond(progress.speedBytesPerSecond),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Receiver: waiting for first byte of an upload.
class ReceiverWaitingBanner extends StatelessWidget {
  const ReceiverWaitingBanner({
    super.key,
    required this.rotation,
  });

  final Animation<double> rotation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          children: [
            RotationTransition(
              turns: rotation,
              child: Icon(
                Icons.download_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for files',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Keep this screen open. The sender should pick files and tap Send.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: null,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Receiver: bytes streaming in.
class ReceiverReceivingBanner extends StatelessWidget {
  const ReceiverReceivingBanner({super.key, required this.state});

  final ReceiverReceiving state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTotal = state.bytesTotal != null && state.bytesTotal! > 0;
    final pct = hasTotal ? state.percent : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Receiving',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: hasTotal ? state.fraction : null,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  hasTotal ? '$pct%' : _bytesLabel(state.bytesReceived),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  formatBytesPerSecond(state.speedBytesPerSecond),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bytesLabel(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
