import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Linear progress bar (8 px; 6 px for audio), animated, fills from the
/// reading-start edge (right in RTL).
class SpiritualProgressBar extends StatelessWidget {
  const SpiritualProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.trackColor,
    this.fillColor,
    this.duration,
    this.semanticLabel,
  });

  /// 0..1.
  final double value;
  final double height;
  final Color? trackColor;
  final Color? fillColor;

  /// Defaults to the `base` motion token; pass [Duration.zero] for linear
  /// playback progress driven by a stream.
  final Duration? duration;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final d = SpiritualMotion.of(context, duration ?? SpiritualMotion.base);
    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: trackColor ?? t.track,
            alignment: AlignmentDirectional.centerStart,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: d,
              curve: SpiritualMotion.baseCurve,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                child: ColoredBox(
                  color: fillColor ?? t.accent,
                  child: SizedBox(height: height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
