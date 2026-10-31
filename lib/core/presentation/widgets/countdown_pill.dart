import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_typography.dart';

/// A small pill with a ring that shows the time left (design/gaps SPEC §3.4), e.g. "30s" for a
/// revealed value. Violet while there is time, amber in the last 5 seconds.
///
/// The screen reader hears the label; [announce] makes it a live region, set only at 10 s and
/// at the end so it is not read every second.
class CountdownPill extends StatelessWidget {
  const CountdownPill({
    super.key,
    required this.seconds,
    required this.text,
    required this.semanticLabel,
    this.total = 30,
    this.announce = false,
  });

  final int seconds;
  final int total;
  final String text;
  final String semanticLabel;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final tone = (seconds <= 5 ? SeenRequestStatus.actionRequired : SeenRequestStatus.underReview).colors;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget ring(double fraction) => CustomPaint(size: const Size.square(16), painter: _RingPainter(fraction, tone.fg));
    return Semantics(
      liveRegion: announce,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            reduceMotion
                ? ring(seconds / total)
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: seconds / total),
                    duration: const Duration(milliseconds: 900),
                    builder: (_, value, __) => ring(value),
                  ),
            const SizedBox(width: 6),
            Text(text, style: SeenType.of(context).chipS.copyWith(color: tone.fg)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(1.6, 1.6, size.width - 3.2, size.height - 3.2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(box, paint..color = color.withOpacity(.22));
    canvas.drawArc(box, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
