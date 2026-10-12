import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/services/umm_al_qura_hijri_converter.dart';
import 'package:seen_booking/features/spiritual/di/prayer_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/calc_settings.dart';
import 'package:seen_booking/features/spiritual/domain/entities/compass_reading.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_day.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_location.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_preferences.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reminder.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/prayer_preferences_repository.dart';
import 'package:seen_booking/features/spiritual/domain/services/compass_sensor.dart';
import 'package:seen_booking/features/spiritual/domain/services/location_service.dart';
import 'package:seen_booking/features/spiritual/domain/services/notification_scheduler.dart';
import 'package:seen_booking/features/spiritual/domain/services/prayer_calculator.dart';

/// Deterministic calculator reproducing the approved mockup's times (Makkah,
/// 3 Oct 2026) with the mockup's day-to-day drift. Times are built from local
/// wall-clock fields, so output and goldens do not depend on the machine's
/// time zone.
///
/// Method / madhab / location shift the result by fixed amounts so tests can
/// see that a setting actually reaches the calculation.
class FixedPrayerCalculator implements PrayerCalculator {
  FixedPrayerCalculator();

  int calls = 0;

  static final anchor = DateTime(2026, 10, 3);

  // fajr, sunrise, dhuhr, asr, maghrib, isha (minutes after midnight)
  static const _base = [298, 372, 735, 937, 1084, 1174];
  static const _drift = [0.5, 0.4, -0.3, -0.6, -0.7, -0.7];

  @override
  PrayerDay calculate({
    required PrayerLocation location,
    required DateTime date,
    required CalcMethod method,
    required AsrMadhab madhab,
  }) {
    calls++;
    final d = DateTime(date.year, date.month, date.day);
    final offsetDays = d.difference(anchor).inDays;
    var m = [
      for (var i = 0; i < 6; i++) (_base[i] + _drift[i] * offsetDays).round(),
    ];
    if (method == CalcMethod.muslimWorldLeague) m[0] += 3;
    if (madhab == AsrMadhab.hanafi) m[3] += 30;
    // Eastern cities see the sun earlier: 1 minute per degree of longitude.
    final shift = ((39.8262 - location.longitude) * 1).round();
    m = [for (final v in m) v + shift];
    DateTime at(int minutes) => DateTime(d.year, d.month, d.day, 0, minutes);
    final night = (m[0] + 1440) - m[4];
    return PrayerDay(
      date: d,
      fajr: at(m[0]),
      sunrise: at(m[1]),
      dhuhr: at(m[2]),
      asr: at(m[3]),
      maghrib: at(m[4]),
      isha: at(m[5]),
      midnight: at(m[4] + night ~/ 2),
      lastThird: at(m[4] + night * 2 ~/ 3),
    );
  }

  @override
  double qiblaBearing(PrayerLocation location) => 293;
}

/// Location service with a programmable answer; records what it was asked.
class FakeLocationService implements LocationService {
  FakeLocationService([this.fix = const LocationFound(21.4225, 39.8262)]);

  LocationFix fix;
  final asked = <bool>[];
  int settingsOpened = 0;

  @override
  Future<LocationFix> currentFix({required bool askPermission}) async {
    asked.add(askPermission);
    return fix;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// In-memory prayer preferences with a failure switch.
class InMemoryPrayerPrefs implements PrayerPreferencesRepository {
  InMemoryPrayerPrefs([this.value = const PrayerPreferences()]);

  PrayerPreferences value;
  bool failSave = false;
  int saves = 0;

  @override
  Future<PrayerPreferences> load() async => value;

  @override
  Future<Either<Failure, PrayerPreferences>> save(PrayerPreferences p) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    saves++;
    value = p;
    return Right(p);
  }
}

/// Scheduler that records what it was asked to schedule.
class FakeScheduler implements NotificationScheduler {
  FakeScheduler([this.current = NotificationPermission.granted]);

  NotificationPermission current;

  /// What a permission prompt answers with.
  NotificationPermission onRequest = NotificationPermission.granted;
  List<Reminder> scheduled = const [];
  int replaceCalls = 0;
  int cancelCalls = 0;
  int requests = 0;
  bool throwOnReplace = false;

  @override
  Future<NotificationPermission> permission() async => current;

  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    current = onRequest;
    return current;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    if (throwOnReplace) throw StateError('plugin failure');
    replaceCalls++;
    scheduled = reminders;
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    scheduled = const [];
  }
}

/// A compass whose samples the test pushes by hand.
class FakeCompassSensor implements CompassSensor {
  FakeCompassSensor({bool magnetic = false, this.available = true})
      : headingIsMagnetic = magnetic;

  @override
  final bool headingIsMagnetic;
  bool available;

  final StreamController<CompassReading> _controller =
      StreamController<CompassReading>.broadcast();

  /// How many listeners are attached right now (0 after a cancel).
  int get listeners => _listeners;
  int _listeners = 0;

  @override
  Stream<CompassReading>? get readings {
    if (!available) return null;
    return Stream<CompassReading>.multi((c) {
      _listeners++;
      final sub = _controller.stream.listen(c.add, onError: c.addError);
      c.onCancel = () {
        _listeners--;
        return sub.cancel();
      };
    });
  }

  void emit(double? heading, {double? accuracy = 15}) =>
      _controller.add(CompassReading(heading: heading, accuracy: accuracy));

  void fail() => _controller.addError(StateError('sensor failure'));

  Future<void> dispose() => _controller.close();
}

class FakeDeclination implements DeclinationService {
  FakeDeclination([this.value = 0, this.fail = false]);

  double value;
  bool fail;
  final asked = <(double, double)>[];

  @override
  Future<double> declinationDegrees(double latitude, double longitude) async {
    asked.add((latitude, longitude));
    if (fail) throw StateError('no declination');
    return value;
  }
}

/// A whole prayer module built from the fakes above.
class PrayerHarness {
  PrayerHarness({
    PrayerPreferences? prefs,
    LocationFix? fix,
    NotificationPermission permission = NotificationPermission.granted,
    DateTime? now,
    FakeCompassSensor? compass,
    FakeDeclination? declination,
  })  : compass = compass ?? FakeCompassSensor(),
        declination = declination ?? FakeDeclination(),
        calculator = FixedPrayerCalculator(),
        location = FakeLocationService(fix ?? const LocationFound(21.4225, 39.8262)),
        prefs = InMemoryPrayerPrefs(prefs ?? const PrayerPreferences()),
        scheduler = FakeScheduler(permission),
        // 11:40 on the anchor day: dhuhr (12:15) is 35 minutes away.
        clock = MutableClock(now ?? DateTime(2026, 10, 3, 11, 40)) {
    module = PrayerModule(
      calculator: calculator,
      hijri: const UmmAlQuraHijriConverter(),
      location: location,
      preferences: this.prefs,
      scheduler: scheduler,
      compass: this.compass,
      declination: this.declination,
      clock: clock.call,
    );
  }

  final FakeCompassSensor compass;
  final FakeDeclination declination;
  final FixedPrayerCalculator calculator;
  final FakeLocationService location;
  final InMemoryPrayerPrefs prefs;
  final FakeScheduler scheduler;
  final MutableClock clock;
  late final PrayerModule module;

  void setNow(DateTime t) => clock.now = t;

  void advance(Duration d) => clock.now = clock.now.add(d);
}

class MutableClock {
  MutableClock(this.now);

  DateTime now;

  DateTime call() => now;
}
