import '../entities/app_mode.dart';

/// Remembers which app mode the user last used.
abstract interface class ModeRepository {
  /// Last persisted mode; [AppMode.agent] when nothing is stored or reading
  /// fails (a lost preference must never block launch).
  Future<AppMode> load();
  Future<void> save(AppMode mode);
}
