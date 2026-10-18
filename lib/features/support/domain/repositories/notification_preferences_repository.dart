import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_preferences.dart';

abstract interface class NotificationPreferencesRepository {
  Future<Either<Failure, NotificationPreferences>> get();

  /// Saves all of it; the server answers with what it now holds.
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences preferences);
}
