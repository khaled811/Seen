import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

/// Notification preferences have no operations in the API (there is no push yet,
/// contract section 14), so reading and saving them are `unsupported_operation`:
/// nothing is sent and nothing is faked (DECISIONS P-06).
class NotificationPreferencesRemoteDataSource implements NotificationPreferencesRepository {
  const NotificationPreferencesRemoteDataSource();

  @override
  Future<Either<Failure, NotificationPreferences>> get() async => unsupportedOperation('Notification preferences');

  @override
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences p) async =>
      unsupportedOperation('Saving notification preferences');
}

/// DEBUG ONLY: when a real call fails in a debug build, keeps the preferences in memory
/// so the screen can be used without a backend. Release builds drop the branch
/// (`kDebugMode` is a compile-time constant). Nothing is persisted.
class DebugFallbackNotificationPreferencesRepository implements NotificationPreferencesRepository {
  DebugFallbackNotificationPreferencesRepository(this._real);

  final NotificationPreferencesRepository _real;
  NotificationPreferences _memory = NotificationPreferences.defaults;

  @override
  Future<Either<Failure, NotificationPreferences>> get() async {
    final r = await _real.get();
    if (debugFallbacksEnabled && r.isLeft()) {
      return Right(_memory);
    }
    return r;
  }

  @override
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences p) async {
    final r = await _real.save(p);
    if (debugFallbacksEnabled && r.isLeft()) {
      _memory = p;
      return Right(p);
    }
    return r;
  }
}
