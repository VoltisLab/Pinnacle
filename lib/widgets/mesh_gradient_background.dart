import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft vignette behind screens. Re-tints itself for light vs. dark so the
/// accent blur still reads as warm without washing out the page.
class MeshGradientBackground extends StatelessWidget {
  const MeshGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? const [
            Color(0xFF0B0B0D),
            Color(0xFF0E0E12),
            Color(0xFF0B0B0D),
          ]
        : const [
            Color(0xFFFAF7F0),
            Color(0xFFF5F0E4),
            Color(0xFFFAF7F0),
          ];
    final haloA = isDark ? const Color(0x332A2418) : const Color(0x55D9C089);
    final haloB = isDark ? const Color(0x22181512) : const Color(0x33C5A76A);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: base,
            ),
          ),
        ),
        Positioned(
          right: -80,
          top: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: haloA,
              ),
            ),
          ),
        ),
        Positioned(
          left: -40,
          bottom: 120,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: haloB,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
