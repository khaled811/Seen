import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_mode.dart';
import '../../domain/repositories/mode_repository.dart';

/// [ModeRepository] backed by `shared_preferences`.
class ModeRepositoryImpl implements ModeRepository {
  ModeRepositoryImpl({Future<SharedPreferences>? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance();

  static const storageKey = 'spiritual.last_mode';

  final Future<SharedPreferences> _preferences;

  @override
  Future<AppMode> load() async {
    try {
      final stored = (await _preferences).getString(storageKey);
      return AppMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => AppMode.agent,
      );
    } catch (_) {
      return AppMode.agent;
    }
  }

  @override
  Future<void> save(AppMode mode) async {
    try {
      await (await _preferences).setString(storageKey, mode.name);
    } catch (_) {
      // A preference that fails to persist only costs the user one extra tap
      // on next launch; never surface it.
    }
  }
}
