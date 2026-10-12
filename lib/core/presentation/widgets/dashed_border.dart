import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle outline over [child] (Figma
/// `border-dashed`): used by "coming soon" tiles and upload drop zones.
class SeenDashedBorder extends StatelessWidget {
  const SeenDashedBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: color,
          radius: radius,
          strokeWidth: strokeWidth,
          dash: dash,
          gap: gap,
        ),
        child: child,
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect.deflate(strokeWidth / 2), Radius.circular(radius)));
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth || old.dash != dash || old.gap != gap;
}
