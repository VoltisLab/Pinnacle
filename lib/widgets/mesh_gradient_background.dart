import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft vignette and gold haze behind screens.
class MeshGradientBackground extends StatelessWidget {
  const MeshGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B0B0D),
                Color(0xFF0E0E12),
                Color(0xFF0B0B0D),
              ],
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x332A2418),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x22181512),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
