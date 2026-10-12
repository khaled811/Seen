import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../domain/entities/prayer_day.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/prayer_preferences.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import 'prayer_texts.dart';

/// The seven rows of the day: name, alert mode, time and the alert button.
class PrayerRowsCard extends StatelessWidget {
  const PrayerRowsCard({
    super.key,
    required this.day,
    required this.prefs,
    required this.reference,
    required this.now,
    required this.next,
    required this.onCycle,
  });

  final PrayerDay day;
  final PrayerPreferences prefs;
  final DateTime reference;
  final DateTime now;

  /// The next prayer (today only); highlighted with a countdown badge.
  final PrayerId? next;
  final ValueChanged<PrayerId> onCycle;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(SpiritualRadius.card),
        border: Border.all(color: t.borderCard),
        boxShadow: SpiritualTokens.cardShadow,
      ),
      child: Column(
        children: [
          for (final (i, (id, time)) in day.entries.indexed) ...[
            if (i > 0) const SizedBox(height: 2),
            PrayerRow(
              id: id,
              time: time,
              mode: prefs.modeOf(id),
              lastThird: day.lastThird,
              past: !time.isAfter(reference),
              active: id == next,
              badge: id == next ? formatShortSpan(time.difference(now)) : null,
              onCycle: () => onCycle(id),
            ),
          ],
        ],
      ),
    );
  }
}

class PrayerRow extends StatelessWidget {
  const PrayerRow({
    super.key,
    required this.id,
    required this.time,
    required this.mode,
    required this.lastThird,
    required this.past,
    required this.active,
    required this.onCycle,
    this.badge,
  });

  final PrayerId id;
  final DateTime time;
  final AlertMode mode;
  final DateTime lastThird;
  final bool past;
  final bool active;
  final String? badge;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final nameColor = active ? t.accent : (past ? t.inkMuted : t.inkPrimary);
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? t.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: SpiritualSpace.s8,
                  children: [
                    Text(
                      id.nameAr,
                      style: SpiritualType.bodyStrong.copyWith(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                        color: nameColor,
                      ),
                    ),
                    if (active && badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'بعد $badge',
                          style: SpiritualType.micro.copyWith(color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpiritualSpace.s2),
                AnimatedSwitcher(
                  duration: SpiritualMotion.of(context, SpiritualMotion.fast),
                  child: Text(
                    PrayerTexts.rowSubtitle(id, mode, lastThird),
                    key: ValueKey(mode),
                    style: SpiritualType.micro.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: active ? t.inkBody : t.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpiritualSpace.s8),
          Text(
            formatClock12(time),
            style: SpiritualType.section.copyWith(
              color: past ? t.inkMuted : t.inkPrimary,
            ),
          ),
          const SizedBox(width: SpiritualSpace.s12),
          _AlertButton(
            label:
                'تنبيه ${id.nameAr}: ${PrayerTexts.modeName(mode)}، اضغط للتغيير',
            mode: mode,
            active: active,
            onTap: onCycle,
          ),
        ],
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.label,
    required this.mode,
    required this.active,
    required this.onTap,
  });

  final String label;
  final AlertMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.control);
    final icon = switch (mode) {
      AlertMode.sound => Icons.notifications_outlined,
      AlertMode.vibrate => Icons.vibration,
      AlertMode.silent => Icons.notifications_off_outlined,
    };
    final color = mode == AlertMode.silent
        ? t.inkMuted
        : (active ? t.accent : t.inkPrimary);
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.94,
      borderRadius: radius,
      child: Container(
        width: SpiritualSpace.minTap,
        height: SpiritualSpace.minTap,
        decoration: BoxDecoration(
          color: active ? t.surface : t.surfaceMuted,
          borderRadius: radius,
          border: Border.all(color: active ? t.accentMid : t.borderCard),
        ),
        child: AnimatedSwitcher(
          duration: SpiritualMotion.of(context, SpiritualMotion.fast),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: Icon(icon, key: ValueKey(mode), size: 22, color: color),
        ),
      ),
    );
  }
}

/// The hint under the list.
class PrayerAlertHint extends StatelessWidget {
  const PrayerAlertHint({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Text(
      SpiritualStrings.alertHint,
      textAlign: TextAlign.center,
      style: SpiritualType.micro.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: t.inkMuted,
      ),
    );
  }
}
