// A 4 dp progress bar (ink on track) for one file row inside a list, the only linear bar the
// loading system keeps. The main progress of an upload uses SeenSkyProgress instead.
// Determinate when [value] is given; otherwise a short segment sweeps (reduce motion: a still
// segment). Owns one controller, created lazily and disposed in dispose.
import 'package:flutter/material.dart';

import 'seen_mark.dart';

class SeenThinProgress extends StatefulWidget {
  const SeenThinProgress(
      {super.key, this.value, this.colors = const SeenLoaderColors()});

  /// 0..1, or null while the size is unknown.
  final double? value;
  final SeenLoaderColors colors;

  @override
  State<SeenThinProgress> createState() => _SeenThinProgressState();
}

class _SeenThinProgressState extends State<SeenThinProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.value == null && !seenReduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(SeenThinProgress old) {
    super.didUpdateWidget(old);
    if (widget.value != null) {
      _c.stop();
    } else if (!seenReduceMotion(context) && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final value = widget.value;
    return Semantics(
      value: value == null ? null : '${(clamp01(value) * 100).round()}%',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: ColoredBox(
            color: colors.track,
            child: value != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                        widthFactor: clamp01(value),
                        child: ColoredBox(color: colors.ink)),
                  )
                : AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      // A 30 % segment travelling start -> end.
                      final x = -1 + _c.value * 2.3;
                      return Align(
                        alignment: AlignmentDirectional(x.clamp(-1.0, 1.0), 0),
                        child: FractionallySizedBox(
                            widthFactor: .3,
                            child: ColoredBox(color: colors.ink)),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
