import 'dart:async';

import '../data/repositories/prayer_preferences_repository_impl.dart';
import '../data/services/adhan_prayer_calculator.dart';
import '../data/services/flutter_compass_sensor.dart';
import '../data/services/geolocator_location_service.dart';
import '../data/services/platform_declination_service.dart';
import '../data/services/local_notification_scheduler.dart';
import '../data/services/umm_al_qura_hijri_converter.dart';
import '../domain/repositories/prayer_preferences_repository.dart';
import '../domain/services/compass_sensor.dart';
import '../domain/services/hijri_converter.dart';
import '../domain/services/location_service.dart';
import '../domain/services/notification_scheduler.dart';
import '../domain/services/prayer_calculator.dart';
import '../domain/usecases/prayer_usecases.dart';
import '../domain/usecases/resolve_location_usecase.dart';
import '../domain/utils/reminder_planner.dart';

/// Composition root for prayer times: calculator, location, preferences,
/// reminders. App-wide singleton (the screen, the dashboard and the app-open
/// reminder refresh all share the same services). Tests replace [instance].
class PrayerModule {
  PrayerModule({
    PrayerCalculator? calculator,
    HijriConverter? hijri,
    LocationService? location,
    PrayerPreferencesRepository? preferences,
    NotificationScheduler? scheduler,
    CompassSensor? compass,
    DeclinationService? declination,
    DateTime Function()? clock,
  })  : calculator = calculator ?? const AdhanPrayerCalculator(),
        hijri = hijri ?? const UmmAlQuraHijriConverter(),
        location = location ?? const GeolocatorLocationService(),
        preferences = preferences ?? PrayerPreferencesRepositoryImpl(),
        scheduler = scheduler ?? LocalNotificationScheduler(),
        compass = compass ?? const FlutterCompassSensor(),
        declination = declination ?? const PlatformDeclinationService(),
        clock = clock ?? DateTime.now;

  static PrayerModule instance = PrayerModule();

  final PrayerCalculator calculator;
  final HijriConverter hijri;
  final LocationService location;
  final PrayerPreferencesRepository preferences;
  final NotificationScheduler scheduler;
  final CompassSensor compass;
  final DeclinationService declination;
  final DateTime Function() clock;

  ReminderPlanner get planner => ReminderPlanner(calculator);
  GetPrayerDayUseCase get getDay => GetPrayerDayUseCase(calculator);
  GetHijriMonthUseCase get getMonth => GetHijriMonthUseCase(calculator, hijri);
  GetPreferencesUseCase get getPreferences => GetPreferencesUseCase(preferences);
  SavePreferencesUseCase get savePreferences => SavePreferencesUseCase(preferences);
  SyncRemindersUseCase get syncReminders => SyncRemindersUseCase(scheduler, planner);
  CheckNotificationPermissionUseCase get notificationPermission =>
      CheckNotificationPermissionUseCase(scheduler);
  RequestNotificationPermissionUseCase get requestNotifications =>
      RequestNotificationPermissionUseCase(scheduler);
  ResolveLocationUseCase get resolveLocation =>
      ResolveLocationUseCase(location, preferences, clock: clock);

  /// Re-plans the next week of reminders. Called whenever the hub opens so the
  /// rolling window never runs dry. Never prompts and never throws.
  Future<void> refreshReminders() async {
    try {
      final resolved = await resolveLocation(askPermission: false, preferCached: true);
      final prefs = await preferences.load();
      await syncReminders(location: resolved.location, prefs: prefs, now: clock());
    } catch (_) {
      // Reminders are best-effort in the background; the prayer screen
      // reports scheduling problems to the user.
    }
  }
}
