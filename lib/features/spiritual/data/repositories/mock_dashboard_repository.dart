import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/entities/day_prayers.dart';
import '../../domain/entities/hijri_date.dart';
import '../../domain/entities/rite_mode.dart';
import '../../domain/entities/tawaf_session.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/reader_state_repository.dart';
import '../../domain/repositories/tawaf_session_repository.dart';
import 'dashboard_reading.dart';

/// Fixed fixture standing in for live services (prayer calculation, Hijri
/// calendar, location, persisted sessions) until M3–M5 replace each piece.
/// Matches the approved `Main.dc.html` artboard.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository({
    DateTime Function()? clock,
    this.withActiveRite = true,
    this.sessions,
    this.readerState,
    this.quran,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final bool withActiveRite;

  /// When given, the active rite comes from the real persisted session
  /// (null when none) instead of the fixture.
  final TawafSessionRepository? sessions;

  /// When both are given, the reading card shows the real last-read surah and
  /// page (progress counts stay mocked until daily goals exist).
  final ReaderStateRepository? readerState;
  final QuranRepository? quran;

  @override
  Future<Either<Failure, DashboardSnapshot>> load() async {
    final now = _clock();
    final stored = sessions;
    final TawafSession? persisted =
        stored == null ? null : (await stored.load()).getOrElse((_) => null);
    final reading = await loadReadingProgress(readerState: readerState, quran: quran);
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return Right(
      DashboardSnapshot(
        city: 'مكة المكرمة',
        hijri: const HijriDate(day: 14, monthName: 'ربيع الآخر', year: 1448),
        prayers: DayPrayers([
          PrayerTime(PrayerSlot.fajr, at(4, 58)),
          PrayerTime(PrayerSlot.dhuhr, at(12, 15)),
          PrayerTime(PrayerSlot.asr, at(15, 37)),
          PrayerTime(PrayerSlot.maghrib, at(18, 4)),
          PrayerTime(PrayerSlot.isha, at(19, 34)),
        ]),
        reading: reading,
        activeRite: stored != null
            ? persisted
            : withActiveRite
            ? TawafSession(
                mode: RiteMode.tawaf,
                currentLap: 3,
                done: false,
                startedAt: now.subtract(const Duration(minutes: 40)),
                lapTimestamps: [
                  now.subtract(const Duration(minutes: 25)),
                  now.subtract(const Duration(minutes: 12)),
                ],
              )
            : null,
      ),
    );
  }
}
