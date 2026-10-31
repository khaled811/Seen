// SeenSkyProgress: determinate progress. The window fills with sky from the bottom as `value`
// goes 0 -> 1 (top edge at y = 129 - value * 117), clouds drift right -> left (7 s and 10 s
// periods), the "س" is ink above the sky and white below it. Always show the % next to it
// with the app's own digits. Value changes animate over 250 ms ease-out.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'seen_mark.dart';

class SeenSkyProgress extends StatefulWidget {
  const SeenSkyProgress(
      {super.key,
      required this.value,
      this.height = 92,
      this.colors = const SeenLoaderColors()});

  final double value;
  final double height;
  final SeenLoaderColors colors;

  @override
  State<SeenSkyProgress> createState() => _SeenSkyProgressState();
}

class _SeenSkyProgressState extends State<SeenSkyProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clouds =
      AnimationController(vsync: this, duration: const Duration(seconds: 70));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (seenReduceMotion(context)) {
      _clouds.stop();
    } else if (!_clouds.isAnimating) {
      _clouds.repeat();
    }
  }

  @override
  void dispose() {
    _clouds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = clamp01(widget.value);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, value, _) => AnimatedBuilder(
            animation: _clouds,
            builder: (context, _) => CustomPaint(
              size: seenMarkSize(widget.height),
              // Seconds; 70 = lcm(7, 10).
              painter: _SkyPainter(
                  value: value,
                  cloudT: _clouds.value * 70,
                  colors: widget.colors),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(
      {required this.value, required this.cloudT, required this.colors});

  final double value, cloudT;
  final SeenLoaderColors colors;

  void _cloud(Canvas canvas, Offset c, double scale, Paint p) {
    canvas.drawOval(
        Rect.fromCenter(center: c, width: 26 * scale, height: 14 * scale), p);
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(9 * scale, -4 * scale),
            width: 18 * scale,
            height: 14 * scale),
        p);
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-10 * scale, 2 * scale),
            width: 16 * scale,
            height: 10 * scale),
        p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 140);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - 140 * s) / 2);
    canvas.scale(s);

    final skyTop = 129 - value * 117;
    final skyRect = Rect.fromLTRB(0, skyTop, 120, 140);
    final airRect = Rect.fromLTRB(0, 0, 120, skyTop);

    canvas.save();
    canvas.clipRRect(SeenMarkGeometry.windowInner);
    canvas.drawRect(const Rect.fromLTWH(11, 7, 99, 127),
        Paint()..color = colors.windowFill);
    canvas.save();
    canvas.clipRect(skyRect);
    canvas.drawRect(
      const Rect.fromLTWH(11, 7, 99, 127),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyBottom],
        ).createShader(const Rect.fromLTWH(11, 7, 99, 127)),
    );
    final cloudPaint = Paint()..color = const Color(0xE6FFFFFF);
    // Drift right -> left, 7 s and 10 s periods.
    double x(double period, double offset) =>
        130 - (((cloudT + offset) % period) / period) * 200;
    _cloud(canvas, Offset(x(7, 3.6), 112), 1, cloudPaint);
    _cloud(canvas, Offset(x(10, 4), 40), .8, cloudPaint);
    canvas.drawRect(Rect.fromLTWH(0, skyTop, 120, 2.5),
        Paint()..color = const Color(0x73FFFFFF));
    canvas.restore();
    canvas.restore();

    Paint glyph(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..color = c;
    void drawGlyph(Color c) {
      canvas.drawPath(
          SeenMarkGeometry.toothPath(), glyph(c, SeenMarkGeometry.toothStroke));
      canvas.drawPath(
          SeenMarkGeometry.smilePath(), glyph(c, SeenMarkGeometry.smileStroke));
    }

    canvas.save();
    canvas.clipRect(airRect);
    drawGlyph(colors.ink);
    canvas.restore();
    canvas.save();
    canvas.clipRect(skyRect);
    drawGlyph(const Color(0xFFFFFFFF));
    canvas.restore();

    canvas.drawRRect(
      SeenMarkGeometry.window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(SeenMarkGeometry.windowStroke, 2 / s)
        ..color = colors.ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.value != value || old.cloudT != cloudT || old.colors != colors;
}
