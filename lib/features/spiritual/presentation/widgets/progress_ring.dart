import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Single continuous arc (tasbeeh): starts at 12 o'clock, sweeps
/// counter-clockwise with round caps. The sweep animates over [duration].
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 272,
    this.strokeWidth = 14,
    this.color,
    this.trackColor,
    this.duration = const Duration(milliseconds: 160),
    this.child,
    this.semanticLabel,
  });

  /// 0..1.
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Duration duration;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: value.clamp(0.0, 1.0)),
                  duration: SpiritualMotion.of(context, duration),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => CustomPaint(
                    painter: _ProgressRingPainter(
                      value: v,
                      strokeWidth: strokeWidth,
                      color: color ?? t.accent,
                      trackColor: trackColor ?? t.track,
                    ),
                  ),
                ),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(rect.center, radius, paint);
    if (value <= 0) return;
    paint.color = color;
    canvas.drawArc(rect, -math.pi / 2, -2 * math.pi * value, false, paint);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor;
}
