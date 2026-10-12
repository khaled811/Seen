import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Manages the app's [ThemeMode] and persists the user's choice. Mirrors
/// `LocaleCubit`'s shape exactly.
///
/// `flutter_secure_storage` opens/closes its own platform channel per call
/// and holds no subscription or timer, so this cubit owns no disposable
/// resource and needs no `close()` override.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit({FlutterSecureStorage? storage, Logger? logger})
      : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger(),
        super(defaultThemeMode) {
    _restore();
  }

  /// Respect the system setting until the user chooses otherwise.
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  static const String _storageKey = 'theme_mode';

  final FlutterSecureStorage _storage;
  final Logger _logger;

  Future<void> _restore() async {
    try {
      final name = await _storage.read(key: _storageKey);
      if (name == null) return;
      final restored = ThemeMode.values.where((m) => m.name == name).firstOrNull;
      if (restored != null && !isClosed && restored != state) {
        emit(restored);
      }
    } catch (e, st) {
      // Corrupt/unavailable secure storage must never crash startup — the
      // cubit simply keeps the default (system) theme mode.
      _logger.w('Failed to restore persisted theme mode', error: e, stackTrace: st);
    }
  }

  /// Sets [mode] and persists it. No-ops if it matches the current state.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    try {
      await _storage.write(key: _storageKey, value: mode.name);
    } catch (e, st) {
      _logger.w('Failed to persist theme mode', error: e, stackTrace: st);
    }
  }

  /// Cycles system -> light -> dark -> system, for a single toggle control.
  Future<void> toggleThemeMode() => setThemeMode(
        switch (state) {
          ThemeMode.system => ThemeMode.light,
          ThemeMode.light => ThemeMode.dark,
          ThemeMode.dark => ThemeMode.system,
        },
      );
}
