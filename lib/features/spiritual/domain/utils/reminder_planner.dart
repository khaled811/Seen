import '../../core/arabic_digits.dart';
import '../../core/time_format.dart';
import '../entities/prayer_id.dart';
import '../entities/prayer_location.dart';
import '../entities/prayer_preferences.dart';
import '../entities/reminder.dart';
import '../services/prayer_calculator.dart';

/// Turns the user's alert choices into the list of notifications to schedule.
///
/// Pure: depends only on its inputs and the injected [PrayerCalculator].
///
/// iOS keeps at most 64 pending local notifications, so the plan is capped at
/// [maxPending] (earliest first). The app re-plans every time it opens, so the
/// window keeps rolling forward.
class ReminderPlanner {
  const ReminderPlanner(this._calculator);

  static const maxPending = 60;

  final PrayerCalculator _calculator;

  List<Reminder> plan({
    required PrayerLocation location,
    required PrayerPreferences prefs,
    required DateTime now,
    int horizonDays = 7,
  }) {
    final out = <Reminder>[];
    final today = dateOnly(now);
    for (var i = 0; i < horizonDays; i++) {
      final date = addDays(today, i);
      final day = _calculator.calculate(
        location: location,
        date: date,
        method: prefs.method,
        madhab: prefs.madhab,
      );
      for (final (id, time) in day.entries) {
        final mode = prefs.modeOf(id);
        if (mode == AlertMode.silent) continue;
        final key = _dateKey(date) * 100 + id.index * 2;
        final body = id == PrayerId.midnight
            ? 'الثلث الأخير من الليل يبدأ ${formatClock12(day.lastThird)}'
            : '${formatClock12(time)} · ${location.name}';
        if (time.isAfter(now)) {
          out.add(Reminder(
            id: key,
            prayer: id,
            time: time,
            mode: mode,
            title: _title(id),
            body: body,
          ));
        }
        final pre = prefs.preAlertMinutes;
        if (pre > 0 && id.isPrayer) {
          final preTime = time.subtract(Duration(minutes: pre));
          if (preTime.isAfter(now)) {
            out.add(Reminder(
              id: key + 1,
              prayer: id,
              time: preTime,
              mode: mode,
              title: toArabicDigits('بعد $pre دقيقة: صلاة ${id.nameAr}'),
              body: body,
              isPreAlert: true,
            ));
          }
        }
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out.length <= maxPending ? out : out.sublist(0, maxPending);
  }

  static String _title(PrayerId id) => switch (id) {
        PrayerId.sunrise => 'تذكير: الشروق',
        PrayerId.midnight => 'تذكير: منتصف الليل',
        _ => 'حان الآن موعد صلاة ${id.nameAr}',
      };

  /// yyMMdd as an int, e.g. 261003.
  static int _dateKey(DateTime d) => (d.year % 100) * 10000 + d.month * 100 + d.day;
}
