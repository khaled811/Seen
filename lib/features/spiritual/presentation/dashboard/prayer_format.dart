import '../../core/arabic_digits.dart';
import '../../domain/entities/day_prayers.dart';

/// Arabic display names of the five prayers.
const prayerNames = {
  PrayerSlot.fajr: 'الفجر',
  PrayerSlot.dhuhr: 'الظهر',
  PrayerSlot.asr: 'العصر',
  PrayerSlot.maghrib: 'المغرب',
  PrayerSlot.isha: 'العشاء',
};

/// Period word shown next to the headline time.
const prayerPeriods = {
  PrayerSlot.fajr: 'فجرًا',
  PrayerSlot.dhuhr: 'ظهرًا',
  PrayerSlot.asr: 'عصرًا',
  PrayerSlot.maghrib: 'مساءً',
  PrayerSlot.isha: 'مساءً',
};

/// 12-hour clock without a period marker, Arabic-Indic digits: "١٢:١٥".
String formatClock(DateTime time) {
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final m = time.minute.toString().padLeft(2, '0');
  return toArabicDigits('$h:$m');
}

/// Countdown as zero-padded HH:MM, Arabic-Indic digits: "٠٠:٣٥".
String formatCountdown(int minutes) {
  final safe = minutes < 0 ? 0 : minutes;
  final h = (safe ~/ 60).toString().padLeft(2, '0');
  final m = (safe % 60).toString().padLeft(2, '0');
  return toArabicDigits('$h:$m');
}
