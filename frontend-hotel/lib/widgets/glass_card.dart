import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted-glass panel: blurred backdrop + translucent white fill + a thin
/// light border to catch the edge highlight. Sits on top of the maroon
/// gradient background. Text inside should stay dark (Colors.black87-ish)
/// since the fill is light, even translucent - that keeps contrast solid
/// regardless of what gradient colour is showing through behind it.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The maroon/black "glassy" backdrop used behind glass cards - a diagonal
/// gradient plus a couple of soft blurred colour blobs for depth, instead
/// of a flat empty background.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B0A14), Color(0xFF7A1F2B), Color(0xFF1A1A1A)],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: _blob(const Color(0xFFB23A4E), 220),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: _blob(const Color(0xFF5C0F1C), 260),
        ),
        child,
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
