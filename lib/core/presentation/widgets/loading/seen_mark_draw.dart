// SeenMarkDraw: the mark writes itself. 2800 ms loop; each stroke draws, holds, then erases
// forward (window 0-32 % / 72-94 %, tooth 22-42 % / 76-95 %, smile 36-58 % / 80-97 %), curve
// cubic-bezier(.65, 0, .35, 1). Reduce motion: the complete mark, static.
// For boot and for blocking waits without a known progress.
import 'package:flutter/material.dart';

import 'seen_mark.dart';

class SeenMarkDraw extends StatefulWidget {
  const SeenMarkDraw(
      {super.key, this.height = 96, this.colors = const SeenLoaderColors()});

  const SeenMarkDraw.onDark({super.key, this.height = 120})
      : colors = const SeenLoaderColors.onDark();

  final double height;
  final SeenLoaderColors colors;

  @override
  State<SeenMarkDraw> createState() => _SeenMarkDrawState();
}

class _SeenMarkDrawState extends State<SeenMarkDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));
  static const _curve = Cubic(.65, 0, .35, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (seenReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static SeenSeg _seg(double t, double d0, double d1, double e0, double e1) {
    if (t < d0) return SeenSeg.none;
    if (t < d1) return SeenSeg(0, _curve.transform((t - d0) / (d1 - d0)));
    if (t < e0) return SeenSeg.full;
    if (t < e1) return SeenSeg(_curve.transform((t - e0) / (e1 - e0)), 1);
    return SeenSeg.none;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = seenReduceMotion(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return CustomPaint(
              size: seenMarkSize(widget.height),
              painter: SeenMarkPainter(
                ink: widget.colors.ink,
                track: widget.colors.track,
                window: reduce ? SeenSeg.full : _seg(t, 0, .32, .72, .94),
                tooth: reduce ? SeenSeg.full : _seg(t, .22, .42, .76, .95),
                smile: reduce ? SeenSeg.full : _seg(t, .36, .58, .80, .97),
              ),
            );
          },
        ),
      ),
    );
  }
}
