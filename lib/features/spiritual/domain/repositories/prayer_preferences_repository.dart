import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/prayer_preferences.dart';

abstract interface class PrayerPreferencesRepository {
  /// Stored preferences, or the defaults when nothing is stored or the store
  /// cannot be read (a lost preference must never block prayer times).
  Future<PrayerPreferences> load();

  /// Persists [preferences] before returning.
  Future<Either<Failure, PrayerPreferences>> save(PrayerPreferences preferences);
}
