import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../core/time_format.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/usecases/prayer_usecases.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';

/// Row height of the month table: fixed, so "scroll to today" is exact.
const monthRowExtent = 56.0;
const monthHeaderExtent = 44.0;

/// Row height for the current text scale: still fixed (so "scroll to today" is
/// exact) but tall enough for two stacked lines at large accessibility sizes.
double monthRowExtentOf(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return monthRowExtent * (1 + (scale.clamp(1.0, 2.0) - 1) * 0.6);
}

/// The Hijri month as a table (docs/03 §5): day, fajr, sunrise, dhuhr, asr,
/// maghrib, isha. Built as slivers so only visible rows are laid out.
class MonthTableSliver extends StatelessWidget {
  const MonthTableSliver({super.key, required this.month, required this.today});

  final HijriMonth month;
  final DateTime today;

  static const _columns = [
    PrayerId.fajr,
    PrayerId.sunrise,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha,
  ];

  /// Index of today's row, or null when today is not in [month].
  static int? todayIndex(HijriMonth month, DateTime today) {
    for (var i = 0; i < month.days.length; i++) {
      final d = month.days[i].date;
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final todayIdx = todayIndex(month, today);
    final rowExtent = monthRowExtentOf(context);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(SpiritualRadius.card),
        border: Border.all(color: t.borderCard),
        boxShadow: SpiritualTokens.cardShadow,
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(8),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(SpiritualTokens.of(context).surface),
            ),
            SliverFixedExtentList(
              itemExtent: rowExtent,
              delegate: SliverChildBuilderDelegate(
                (context, i) => _DayRow(
                  index: i,
                  day: month.days[i],
                  isToday: i == todayIdx,
                ),
                childCount: month.days.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the column headings in view while the days scroll under them.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate(this.background);

  final Color background;

  @override
  double get minExtent => monthHeaderExtent;

  @override
  double get maxExtent => monthHeaderExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: background, child: const _HeaderRow());

  @override
  bool shouldRebuild(_HeaderDelegate old) => old.background != background;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    TextStyle style() => SpiritualType.micro.copyWith(color: t.inkBody);
    return SizedBox(
      height: monthHeaderExtent,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              SpiritualStrings.colDay,
              textAlign: TextAlign.center,
              style: style(),
            ),
          ),
          for (final id in MonthTableSliver._columns)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(id.nameAr, style: style()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.day,
    required this.isToday,
  });

  final int index;
  final MonthDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final date = day.date;
    final bg = isToday
        ? t.accentTint
        : (index.isOdd ? const Color(0xFFF0FAFB) : Colors.transparent);
    return Semantics(
      container: true,
      label: toArabicDigits(
        '${day.hijriDay}، ${date.day} ${gregorianMonthName(date.month)}',
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    toArabicDigits(day.hijriDay),
                    style: SpiritualType.body.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: isToday ? t.accent : t.inkPrimary,
                    ),
                  ),
                  Text(
                    toArabicDigits('${date.day} ${gregorianMonthName(date.month)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SpiritualType.micro.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: t.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            for (final id in MonthTableSliver._columns)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatClockShort(day.day.timeOf(id)),
                    style: SpiritualType.caption.copyWith(
                      color: id == PrayerId.sunrise ? t.inkBody : t.inkPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
