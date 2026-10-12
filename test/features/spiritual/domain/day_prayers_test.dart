import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/day_prayers.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reading_progress.dart';

DateTime _at(int h, int m, [int s = 0]) => DateTime(2026, 10, 3, h, m, s);

final _day = DayPrayers([
  PrayerTime(PrayerSlot.fajr, _at(4, 58)),
  PrayerTime(PrayerSlot.dhuhr, _at(12, 15)),
  PrayerTime(PrayerSlot.asr, _at(15, 37)),
  PrayerTime(PrayerSlot.maghrib, _at(18, 4)),
  PrayerTime(PrayerSlot.isha, _at(19, 34)),
]);

void main() {
  group('DayPrayers.next', () {
    test('before fajr -> fajr, nothing past', () {
      final n = _day.next(_at(3, 0));
      expect(n.slot, PrayerSlot.fajr);
      expect(n.pastCount, 0);
      expect(n.isTomorrow, isFalse);
      expect(n.remainingMinutes, 118);
    });

    test('mid-morning -> dhuhr with 35 minutes left', () {
      final n = _day.next(_at(11, 40));
      expect(n.slot, PrayerSlot.dhuhr);
      expect(n.index, 1);
      expect(n.pastCount, 1);
      expect(n.remainingMinutes, 35);
    });

    test('remaining minutes round up', () {
      expect(_day.next(_at(12, 14, 1)).remainingMinutes, 1);
      expect(_day.next(_at(12, 14, 59)).remainingMinutes, 1);
    });

    test('exactly at a prayer time moves on to the next prayer', () {
      expect(_day.next(_at(12, 15)).slot, PrayerSlot.asr);
    });

    test('after isha -> tomorrow\'s fajr, everything past', () {
      final n = _day.next(_at(21, 0));
      expect(n.slot, PrayerSlot.fajr);
      expect(n.isTomorrow, isTrue);
      expect(n.pastCount, 5);
      expect(n.time, DateTime(2026, 10, 4, 4, 58));
      expect(n.remainingMinutes, 7 * 60 + 58);
    });
  });

  group('ReadingProgress', () {
    test('fraction and percent', () {
      const p = ReadingProgress(
        surahName: 'الكهف',
        page: 293,
        pagesRead: 3,
        pagesGoal: 5,
      );
      expect(p.fraction, 0.6);
      expect(p.percent, 60);
    });

    test('is clamped at 100 %', () {
      const p = ReadingProgress(
        surahName: 'الكهف',
        page: 1,
        pagesRead: 9,
        pagesGoal: 5,
      );
      expect(p.fraction, 1.0);
    });
  });
}
