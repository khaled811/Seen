import 'package:flutter/material.dart';

import '../../domain/entities/day_prayers.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_pill.dart';
import 'prayer_format.dart';

/// "الصلاة القادمة": name, live countdown pill, headline time and the
/// five-column day timeline. The whole card opens the prayer screen.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    super.key,
    required this.prayers,
    required this.next,
    required this.onTap,
  });

  final DayPrayers prayers;
  final NextPrayer next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final fast = SpiritualMotion.of(context, SpiritualMotion.fast);
    final countdown =
        '${SpiritualStrings.remaining} ${formatCountdown(next.remainingMinutes)}';
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      borderRadius: BorderRadius.circular(SpiritualRadius.card),
      child: SpiritualCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SpiritualStrings.nextPrayer,
                        style: SpiritualType.caption.copyWith(color: t.inkMuted),
                      ),
                      const SizedBox(height: SpiritualSpace.s2),
                      Text(
                        prayerNames[next.slot]!,
                        style: SpiritualType.h1.copyWith(color: t.inkPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpiritualSpace.s8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: fast,
                    child: SpiritualPill(
                      key: ValueKey(countdown),
                      label: countdown,
                      variant: PillVariant.accent,
                      dot: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpiritualSpace.s18),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatClock(next.time),
                      style: SpiritualType.display.copyWith(
                        color: t.inkPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: SpiritualSpace.s10),
                    Text(
                      prayerPeriods[next.slot]!,
                      style: SpiritualType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w500,
                        color: t.inkBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SpiritualSpace.s18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < prayers.times.length; i++) ...[
                  if (i > 0) const SizedBox(width: SpiritualSpace.s6),
                  Expanded(
                    child: _TimelineColumn(
                      prayer: prayers.times[i],
                      state: i < next.pastCount
                          ? _Phase.past
                          : (i == next.index && !next.isTomorrow)
                              ? _Phase.next
                              : _Phase.future,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Phase { past, next, future }

class _TimelineColumn extends StatelessWidget {
  const _TimelineColumn({required this.prayer, required this.state});

  final PrayerTime prayer;
  final _Phase state;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final (bar, nameColor, timeColor, nameWeight, timeWeight) = switch (state) {
      _Phase.past => (t.accentMid, t.inkMuted, t.inkMuted, FontWeight.w500, FontWeight.w500),
      _Phase.next => (t.accent, t.accent, t.inkPrimary, FontWeight.w700, FontWeight.w800),
      _Phase.future => (t.borderControl, t.inkBody, t.inkPrimary, FontWeight.w500, FontWeight.w500),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: SpiritualSpace.s8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            prayerNames[prayer.slot]!,
            style: SpiritualType.caption.copyWith(
              fontSize: 14,
              fontWeight: nameWeight,
              color: nameColor,
            ),
          ),
        ),
        const SizedBox(height: SpiritualSpace.s8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            formatClock(prayer.time),
            style: SpiritualType.caption.copyWith(
              fontWeight: timeWeight,
              color: timeColor,
            ),
          ),
        ),
      ],
    );
  }
}
