import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../core/time_format.dart';
import '../../di/prayer_module.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/entities/day_prayers.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/reader_state_repository.dart';
import '../../domain/repositories/tawaf_session_repository.dart';
import 'dashboard_reading.dart';

/// The real dashboard: prayer times calculated offline for the user's
/// location, the Umm al-Qura Hijri date, the persisted Tawaf session and the
/// last-read position.
class LiveDashboardRepository implements DashboardRepository {
  LiveDashboardRepository({
    required this.prayer,
    required this.sessions,
    required this.readerState,
    required this.quran,
  });

  final PrayerModule prayer;
  final TawafSessionRepository sessions;
  final ReaderStateRepository readerState;
  final QuranRepository quran;

  static const _slots = [
    (PrayerSlot.fajr, PrayerId.fajr),
    (PrayerSlot.dhuhr, PrayerId.dhuhr),
    (PrayerSlot.asr, PrayerId.asr),
    (PrayerSlot.maghrib, PrayerId.maghrib),
    (PrayerSlot.isha, PrayerId.isha),
  ];

  @override
  Future<Either<Failure, DashboardSnapshot>> load() async {
    try {
      // Never prompts: the permission question belongs to the prayer screen.
      final resolved = await prayer.resolveLocation(
        askPermission: false,
        preferCached: true,
      );
      final prefs = await prayer.preferences.load();
      final today = dateOnly(prayer.clock());
      final day = prayer.getDay(
        location: resolved.location,
        prefs: prefs,
        date: today,
      );
      final tomorrow = prayer.getDay(
        location: resolved.location,
        prefs: prefs,
        date: addDays(today, 1),
      );
      return Right(DashboardSnapshot(
        city: resolved.location.name,
        hijri: prayer.hijri.fromGregorian(today),
        prayers: DayPrayers(
          [for (final (slot, id) in _slots) PrayerTime(slot, day.timeOf(id))],
          tomorrowFajr: tomorrow.fajr,
        ),
        reading: await loadReadingProgress(
          readerState: readerState,
          quran: quran,
        ),
        activeRite: (await sessions.load()).getOrElse((_) => null),
      ));
    } catch (e) {
      return Left(CacheFailure('Could not load the dashboard: $e'));
    }
  }
}
