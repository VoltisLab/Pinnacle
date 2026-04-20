import 'dart:async';

import 'package:flutter/material.dart';

/// One-shot celebratory tick dialog. Shown on both sender and receiver
/// the instant a pair handshake completes. Auto-dismisses so users don't
/// have to tap OK to keep moving.
class ConnectedTickDialog extends StatefulWidget {
  const ConnectedTickDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.autoDismissAfter = const Duration(milliseconds: 1400),
  });

  final String title;
  final String subtitle;
  final Duration autoDismissAfter;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    Duration autoDismissAfter = const Duration(milliseconds: 1400),
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConnectedTickDialog(
        title: title,
        subtitle: subtitle,
        autoDismissAfter: autoDismissAfter,
      ),
    );
  }

  @override
  State<ConnectedTickDialog> createState() => _ConnectedTickDialogState();
}

class _ConnectedTickDialogState extends State<ConnectedTickDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _dismissTimer = Timer(widget.autoDismissAfter, () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pop = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    final check = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final scale = 0.4 + 0.6 * pop.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.16),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.55 + 0.45 * pop.value,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                        child: FittedBox(
                          fit: BoxFit.none,
                          child: CustomPaint(
                            size: const Size(34, 34),
                            painter: _CheckPainter(
                              progress: check.value,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Path goes: (7, 18) -> (15, 25) -> (28, 10), roughly a fat check.
    final p1 = Offset(size.width * 0.22, size.height * 0.55);
    final p2 = Offset(size.width * 0.45, size.height * 0.75);
    final p3 = Offset(size.width * 0.82, size.height * 0.28);

    // First leg animates 0..0.45 of progress; second leg 0.45..1.0.
    final firstT = (progress / 0.45).clamp(0.0, 1.0);
    final secondT = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);

    final path = Path()..moveTo(p1.dx, p1.dy);
    final midA = Offset.lerp(p1, p2, firstT)!;
    path.lineTo(midA.dx, midA.dy);
    if (secondT > 0) {
      final midB = Offset.lerp(p2, p3, secondT)!;
      path.lineTo(midB.dx, midB.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
