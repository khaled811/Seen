import '../../core/arabic_digits.dart';
import '../../core/time_format.dart';
import '../../domain/entities/hijri_date.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/usecases/prayer_usecases.dart';
import '../spiritual_strings.dart';

/// Arabic copy derived from prayer data.
abstract final class PrayerTexts {
  static String modeName(AlertMode m) => switch (m) {
        AlertMode.sound => SpiritualStrings.modeSound,
        AlertMode.vibrate => SpiritualStrings.modeVibrate,
        AlertMode.silent => SpiritualStrings.modeSilent,
      };

  /// "أذان كامل" / "تذكير · صامت" / "الثلث الأخير للقيام ١:٢٠ ص · صامت".
  static String rowSubtitle(PrayerId id, AlertMode mode, DateTime lastThird) =>
      switch (id) {
        PrayerId.sunrise => '${SpiritualStrings.reminderPrefix} · ${modeName(mode)}',
        PrayerId.midnight =>
          '${SpiritualStrings.lastThirdPrefix} ${formatClock12(lastThird)} · ${modeName(mode)}',
        _ => modeName(mode),
      };

  /// "مضت" / "مضى" for something already behind us.
  static String past(PrayerId id) => id.isPrayer
      ? SpiritualStrings.pastFeminine
      : SpiritualStrings.pastMasculine;

  /// Selected-marker caption suffix: "بعد ٣٥ دقيقة", "مضت" or "" (other days).
  static String relative(PrayerId id, DateTime time, DateTime now, bool today) {
    if (!today) return '';
    return time.isAfter(now)
        ? formatRelativeFuture(time.difference(now))
        : past(id);
  }

  /// "السبت ١٤ ربيع الآخر".
  static String dayTitle(DateTime date, HijriDate h) =>
      toArabicDigits('${weekdayName(date)} ${h.day} ${h.monthName}');

  /// "ربيع الآخر ١٤٤٨".
  static String monthTitle(HijriMonth m) =>
      toArabicDigits('${m.monthName} ${m.year}');

  /// "سبتمبر – أكتوبر ٢٠٢٦" / "أكتوبر ٢٠٢٦".
  static String gregorianSpan(HijriMonth m) {
    final a = m.days.first.date;
    final b = m.days.last.date;
    if (a.year == b.year && a.month == b.month) {
      return toArabicDigits('${gregorianMonthName(a.month)} ${a.year}');
    }
    if (a.year == b.year) {
      return toArabicDigits(
        '${gregorianMonthName(a.month)} – ${gregorianMonthName(b.month)} ${a.year}',
      );
    }
    return toArabicDigits(
      '${gregorianMonthName(a.month)} ${a.year} – ${gregorianMonthName(b.month)} ${b.year}',
    );
  }
}
