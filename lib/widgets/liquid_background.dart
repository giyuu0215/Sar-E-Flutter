import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[c.background, c.backgroundSecondary],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: -70,
              top: -60,
              child: _GlowOrb(
                color: c.primary.withValues(alpha: dark ? 0.28 : 0.16),
                size: 210,
              ),
            ),
            Positioned(
              right: -60,
              top: 140,
              child: _GlowOrb(
                color: c.accent.withValues(alpha: dark ? 0.14 : 0.12),
                size: 180,
              ),
            ),
            Positioned(
              left: 80,
              bottom: -75,
              child: _GlowOrb(
                color: c.primaryDark.withValues(alpha: dark ? 0.20 : 0.10),
                size: 240,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.expand(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 90, spreadRadius: 30),
        ],
      ),
    );
  }
}
