import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

enum RingSegment { done, current, future }

/// State of each of [segments] arcs when [completed] laps are done. The next
/// arc is `current` unless [showCurrent] is false (e.g. everything finished).
List<RingSegment> ringSegmentStates({
  required int segments,
  required int completed,
  bool showCurrent = true,
}) =>
    [
      for (var i = 0; i < segments; i++)
        if (i < completed)
          RingSegment.done
        else if (showCurrent && i == completed)
          RingSegment.current
        else
          RingSegment.future,
    ];

/// N arc segments around a circle (Tawaf = 7), starting at 12 o'clock and
/// filling counter-clockwise like the Tawaf itself. Colour changes tween.
class SegmentedRing extends StatefulWidget {
  const SegmentedRing({
    super.key,
    this.segments = 7,
    required this.completed,
    this.showCurrent = true,
    this.size = 256,
    this.strokeWidth = 16,
    this.gap = 10,
    this.child,
    this.semanticLabel,
  });

  final int segments;
  final int completed;
  final bool showCurrent;
  final double size;
  final double strokeWidth;

  /// Gap between arcs in logical px, measured along the ring centre line.
  final double gap;
  final Widget? child;
  final String? semanticLabel;

  @override
  State<SegmentedRing> createState() => _SegmentedRingState();
}

class _SegmentedRingState extends State<SegmentedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SpiritualMotion.slow,
    value: 1,
  );
  late List<RingSegment> _from = _states;
  late List<RingSegment> _to = _states;

  List<RingSegment> get _states => ringSegmentStates(
        segments: widget.segments,
        completed: widget.completed,
        showCurrent: widget.showCurrent,
      );

  @override
  void didUpdateWidget(SegmentedRing old) {
    super.didUpdateWidget(old);
    final next = _states;
    if (!_sameStates(next, _to)) {
      _from = _to;
      _to = next;
      _controller.duration = SpiritualMotion.of(context, SpiritualMotion.slow);
      _controller.forward(from: 0);
    }
  }

  static bool _sameStates(List<RingSegment> a, List<RingSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    Color colorOf(RingSegment s) => switch (s) {
          RingSegment.done => t.accent,
          RingSegment.current => t.accentMid,
          RingSegment.future => t.track,
        };
    final from = [for (final s in _from) colorOf(s)];
    final to = [for (final s in _to) colorOf(s)];
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CustomPaint(
                    painter: _SegmentedRingPainter(
                      colors: [
                        for (var i = 0; i < to.length; i++)
                          Color.lerp(from[i], to[i], _controller.value)!,
                      ],
                      strokeWidth: widget.strokeWidth,
                      gap: widget.gap,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        ),
      ),
    );
  }
}

class _SegmentedRingPainter extends CustomPainter {
  _SegmentedRingPainter({
    required this.colors,
    required this.strokeWidth,
    required this.gap,
  });

  final List<Color> colors;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final n = colors.length;
    final step = 2 * math.pi / n;
    final gapAngle = gap / radius;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < n; i++) {
      paint.color = colors[i];
      // Counter-clockwise from 12 o'clock => negative sweep.
      final start = -math.pi / 2 - i * step - gapAngle / 2;
      canvas.drawArc(rect, start, -(step - gapAngle), false, paint);
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter old) =>
      old.strokeWidth != strokeWidth ||
      old.gap != gap ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
