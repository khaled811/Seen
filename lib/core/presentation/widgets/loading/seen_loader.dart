// SeenLoader: the default spinner. A light runs round the airplane window of the Seen mark.
// Tail 34 % of the perimeter at 38 % opacity, head 14 % at full ink; 1100 ms linear
// (2600 ms with "reduce motion": it is the only feedback, so it stays).
import 'package:flutter/material.dart';

import 'seen_mark.dart';

/// [size] is the mark height (16-18 in buttons, 20-24 in fields and toasts, 40 on cards,
/// 64-96 for a centred wait). The glyph "س" shows from 36 up. Decorative: leave
/// [semanticLabel] null when the surrounding container already announces «جاري التحميل».
class SeenLoader extends StatefulWidget {
  const SeenLoader({super.key, this.size = 40, this.color, this.semanticLabel})
      : _onDark = false;

  /// White ink and a 22 % white track, for filled / gradient / dark surfaces.
  const SeenLoader.onDark({super.key, this.size = 18, this.semanticLabel})
      : color = null,
        _onDark = true;

  final double size;

  /// Ink colour; null = brand violet.
  final Color? color;
  final String? semanticLabel;
  final bool _onDark;

  @override
  State<SeenLoader> createState() => _SeenLoaderState();
}

class _SeenLoaderState extends State<SeenLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = Duration(milliseconds: seenReduceMotion(context) ? 2600 : 1100);
    if (_c.duration != d || !_c.isAnimating) {
      _c.duration = d;
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
    final color = widget.color;
    final colors = widget._onDark
        ? const SeenLoaderColors.onDark()
        : (color == null
            ? const SeenLoaderColors()
            : const SeenLoaderColors().withInk(color));
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: seenMarkSize(widget.size),
            painter: SeenMarkPainter(
              ink: colors.ink,
              track: colors.track,
              tracePhase: _c.value,
              showTrack: true,
              showGlyph: widget.size >= 36,
            ),
          ),
        ),
      ),
    );
  }
}
