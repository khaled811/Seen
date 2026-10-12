import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../theme/spiritual_tokens.dart';

/// 44×44 eight-point star badge (two 31 px squares, one rotated 45°) with a
/// centred number. Stroke is neutral, or accent when [highlighted].
class OctagonBadge extends StatelessWidget {
  const OctagonBadge({super.key, required this.number, this.highlighted = false});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final color = highlighted ? t.accent : t.octagonStroke;
    return SizedBox.square(
      dimension: 44,
      child: CustomPaint(
        painter: _OctagonPainter(color),
        child: Center(
          child: Text(
            toArabicDigits(number),
            style: SpiritualType.label.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: highlighted ? t.accent : t.inkPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  _OctagonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    const side = 31.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      const Radius.circular(7),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawRRect(rrect, paint);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OctagonPainter old) => old.color != color;
}
