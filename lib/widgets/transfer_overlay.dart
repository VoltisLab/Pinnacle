import 'package:flutter/material.dart';

import '../state/transfer_overlay_controller.dart';
import 'transfer_format.dart';

/// Wrap the app's home with this so a floating transfer card can appear
/// above any screen (modals, settings, etc.) as long as a transfer is
/// active on [TransferOverlayController.instance].
class TransferOverlay extends StatelessWidget {
  const TransferOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<TransferSnapshot?>(
              valueListenable: TransferOverlayController.instance,
              builder: (context, snapshot, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.5),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: snapshot == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : Padding(
                          key: ValueKey(snapshot.role),
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _TransferCard(snapshot: snapshot),
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.snapshot});

  final TransferSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sending = snapshot.role == TransferRole.sending;
    final accent = sending
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return Material(
      elevation: 10,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sending
                        ? Icons.north_east_rounded
                        : Icons.south_west_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sending ? 'Sending' : 'Receiving',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        snapshot.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  snapshot.bytesTotal > 0 ? '${snapshot.percent}%' : '…',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value:
                    snapshot.bytesTotal > 0 ? snapshot.fraction : null,
                valueColor: AlwaysStoppedAnimation(accent),
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  formatBytesPerSecond(snapshot.bytesPerSecond),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _bytesLabel(snapshot.bytesDone, snapshot.bytesTotal),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bytesLabel(int done, int total) {
    if (total <= 0) return _fmt(done);
    return '${_fmt(done)} / ${_fmt(total)}';
  }

  String _fmt(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1024 * 1024 * 1024) {
      return '${(n / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
