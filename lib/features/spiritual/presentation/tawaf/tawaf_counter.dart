import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/tawaf_session.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/segmented_ring.dart';
import 'tawaf_texts.dart';

/// The 7-segment ring with the lap number (or completion check) in the
/// centre and the guidance line underneath.
class TawafCounter extends StatelessWidget {
  const TawafCounter({super.key, required this.session});

  final TawafSession session;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final base = SpiritualMotion.of(context, SpiritualMotion.base);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedRing(
          completed: session.completedLaps,
          showCurrent: !session.done,
          semanticLabel: session.done
              ? TawafTexts.doneLabel(session.mode)
              : TawafTexts.lapProgress(session),
          child: AnimatedSwitcher(
            duration: base,
            transitionBuilder: _transition,
            child: session.done
                ? _Done(key: const ValueKey('done'), mode: session)
                : _LapNumber(
                    key: ValueKey('lap-${session.currentLap}'),
                    lap: session.currentLap,
                  ),
          ),
        ),
        const SizedBox(height: SpiritualSpace.s4),
        Text(
          TawafTexts.guide(session),
          textAlign: TextAlign.center,
          style: SpiritualType.body.copyWith(
            fontWeight: FontWeight.w700,
            color: t.inkPrimary,
          ),
        ),
      ],
    );
  }

  static Widget _transition(Widget child, Animation<double> animation) {
    final isDone = (child.key as ValueKey<String>).value == 'done';
    if (isDone) {
      // Check circle scales 0.6 -> 1 with the `emphasis` overshoot.
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(
            Tween<double>(begin: 0.6, end: 1)
                .chain(CurveTween(curve: SpiritualMotion.emphasisCurve)),
          ),
          child: child,
        ),
      );
    }
    // New lap number slides up 12 px (of ~112) while fading in.
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.11), end: Offset.zero)
              .chain(CurveTween(curve: SpiritualMotion.baseCurve)),
        ),
        child: child,
      ),
    );
  }
}

class _LapNumber extends StatelessWidget {
  const _LapNumber({super.key, required this.lap});

  final int lap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SpiritualStrings.lap,
              style: SpiritualType.bodyStrong.copyWith(
                fontWeight: FontWeight.w500,
                color: t.inkBody,
              ),
            ),
            Text(
              toArabicDigits(lap),
              style: SpiritualType.counterXL.copyWith(color: t.inkPrimary),
            ),
            Text(
              SpiritualStrings.ofSeven,
              style: SpiritualType.section.copyWith(
                fontSize: 22,
                color: t.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({super.key, required this.mode});

  final TawafSession mode;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 40, color: Colors.white),
            ),
            const SizedBox(height: SpiritualSpace.s12),
            Text(
              TawafTexts.doneLabel(mode.mode),
              style: SpiritualType.h2.copyWith(
                fontSize: 26,
                color: t.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
