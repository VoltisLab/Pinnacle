import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft atmosphere — warm cream in light mode, deep blue at night.
class MeshGradientBackground extends StatelessWidget {
  const MeshGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final List<Color> baseGradient = isLight
        ? const [
            AppTheme.lightCreamCanvas,
            AppTheme.lightCreamMid,
            AppTheme.lightCreamCanvas,
          ]
        : const [
            Color(0xFF0B1220),
            Color(0xFF0F172A),
            Color(0xFF0B1220),
          ];

    final Color orb1 = isLight
        ? const Color(0x26C9A86C)
        : const Color(0x4D3B82F6);
    final Color orb2 = isLight
        ? const Color(0x1AA67C52)
        : const Color(0x331E40AF);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: baseGradient,
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
                color: orb1,
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
                color: orb2,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
