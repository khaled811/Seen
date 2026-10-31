// SeenWindows: the inline loader. Three cabin windows (ratio .82 : 1, radius 36 %) light up in
// turn start -> end (right -> left in RTL), stagger 180 ms, cycle 1200 ms. For the "loading
// more" row of paginated lists, "saving" chips and small inline status. Reduce motion: hold
// (the first window lit).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'seen_mark.dart';

class SeenWindows extends StatefulWidget {
  const SeenWindows({super.key, this.size = 8, this.color});

  /// Window height (6-10 inline, up to 18).
  final double size;
  final Color? color;

  @override
  State<SeenWindows> createState() => _SeenWindowsState();
}

class _SeenWindowsState extends State<SeenWindows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

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

  // 0 -> .35 rise to lit, .35 -> .70 fall, rest dim.
  double _lit(double t) {
    t = t % 1;
    if (t < .35) return Curves.easeInOut.transform(t / .35);
    if (t < .70) return 1 - Curves.easeInOut.transform((t - .35) / .35);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const SeenLoaderColors().ink;
    final reduce = seenReduceMotion(context);
    final d = widget.size;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: d * .55),
                Builder(builder: (_) {
                  final lit =
                      reduce ? (i == 0 ? 1.0 : .4) : _lit(_c.value - i * .15);
                  return Opacity(
                    opacity: .3 + .7 * lit,
                    child: Container(
                      width: d * .82,
                      height: d,
                      decoration: BoxDecoration(
                        color: Color.lerp(color.withOpacity(0), color, lit),
                        border: Border.all(
                            color: color, width: math.max(1.2, d * .2)),
                        borderRadius: BorderRadius.circular(d * .36),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
