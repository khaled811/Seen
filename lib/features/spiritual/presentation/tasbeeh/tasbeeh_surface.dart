import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/tasbeeh.dart';
import '../../domain/utils/tasbeeh_math.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/progress_ring.dart';

/// The big tap target (docs/03 §8): one 32-radius surface holding the
/// progress ring, the count and a hint. The whole surface counts, so it can
/// be hit blind with a thumb.
///
/// Rebuilds only when the progress changes; the count pulse and the ring
/// sweep are driven by their own animations.
class TasbeehSurface extends StatelessWidget {
  const TasbeehSurface({
    super.key,
    required this.progress,
    required this.dhikrLabel,
    required this.onTap,
  });

  final TasbeehProgress progress;
  final String dhikrLabel;
  final VoidCallback onTap;

  static const ringSize = 272.0;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final done = progress.complete;
    final open = progress.target.isOpen;
    final count = toArabicDigits(progress.count);
    final surface = done ? Color.lerp(t.surface, t.sageTint, 0.5)! : t.surface;
    final border = done ? Color.lerp(t.sageTint, t.sage, 0.3)! : t.borderCard;
    final radius = BorderRadius.circular(SpiritualRadius.surface);
    return PressScale(
      onTap: onTap,
      scale: 0.985,
      borderRadius: radius,
      semanticLabel: '$dhikrLabel — العدد $count، اضغط للتسبيح',
      child: AnimatedContainer(
        duration: SpiritualMotion.of(context, SpiritualMotion.base),
        padding: const EdgeInsets.all(SpiritualSpace.s16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: radius,
          border: Border.all(color: border),
          boxShadow: SpiritualTokens.cardShadow,
        ),
        child: Center(
          // On a short or heavily scaled screen the surface shrinks as a
          // whole instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Ring(progress: progress, count: count, open: open),
                const SizedBox(height: SpiritualSpace.s14),
                _Hint(complete: done),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.count, required this.open});

  final TasbeehProgress progress;
  final String count;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final target = open
        ? SpiritualStrings.noLimit
        : '/ ${toArabicDigits(progress.target.value)}';
    return ExcludeSemantics(
      child: _SweepRing(
        value: TasbeehMath.ringValue(progress),
        color: progress.complete ? t.sage : t.accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _CountPulse(
                  count: progress.count,
                  child: Text(
                    count,
                    style: SpiritualType.counterL.copyWith(color: t.inkPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: SpiritualSpace.s2),
            Text(
              target,
              style: SpiritualType.section.copyWith(
                fontSize: 24,
                color: t.inkBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [ProgressRing] that sweeps quickly (160 ms) while counting and slowly when
/// it winds back after a reset or a round, so a reset reads as a reset.
class _SweepRing extends StatefulWidget {
  const _SweepRing({
    required this.value,
    required this.color,
    required this.child,
  });

  final double value;
  final Color color;
  final Widget child;

  @override
  State<_SweepRing> createState() => _SweepRingState();
}

class _SweepRingState extends State<_SweepRing> {
  Duration _duration = const Duration(milliseconds: 160);

  @override
  void didUpdateWidget(_SweepRing old) {
    super.didUpdateWidget(old);
    if (widget.value < old.value) {
      _duration = const Duration(milliseconds: 520);
    } else if (widget.value > old.value) {
      _duration = const Duration(milliseconds: 160);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return ProgressRing(
      value: widget.value,
      size: TasbeehSurface.ringSize,
      color: widget.color,
      trackColor: t.segmentTrack,
      duration: _duration,
      child: widget.child,
    );
  }
}

/// Count appears instantly; a 1.0 → 1.04 → 1.0 pulse confirms each tap.
class _CountPulse extends StatefulWidget {
  const _CountPulse({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<_CountPulse> createState() => _CountPulseState();
}

class _CountPulseState extends State<_CountPulse>
    with SingleTickerProviderStateMixin {
  // Owned here: created with the state, disposed in dispose().
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
  ]);

  @override
  void didUpdateWidget(_CountPulse old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count && !SpiritualMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller.drive(_scale),
      child: widget.child,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return AnimatedContainer(
      duration: SpiritualMotion.of(context, SpiritualMotion.base),
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(
        horizontal: SpiritualSpace.s14,
        vertical: SpiritualSpace.s4,
      ),
      decoration: BoxDecoration(
        color: complete ? t.sageTint : t.surfaceMuted,
        borderRadius: BorderRadius.circular(SpiritualRadius.pill),
      ),
      child: Text(
        complete ? SpiritualStrings.roundComplete : SpiritualStrings.tapToCount,
        style: SpiritualType.label.copyWith(
          color: complete ? t.sageInk : t.inkBody,
        ),
      ),
    );
  }
}
