import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import 'app_language.dart';

/// Manages the app's active [Locale] and persists the user's choice.
///
/// `flutter_secure_storage` opens/closes its own platform channel per call
/// and holds no subscription or timer, so this cubit owns no disposable
/// resource and needs no `close()` override.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit({FlutterSecureStorage? storage, Logger? logger, AppLanguage? language})
      : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger(),
        _language = language,
        super(defaultLocale) {
    _language?.code = defaultLocale.languageCode;
    _restore();
  }

  /// Per the BRD, Arabic is the default until a saved preference says
  /// otherwise.
  static const Locale defaultLocale = Locale('ar');

  /// Locales the app ships translations for. Keep in sync with
  /// `l10n.yaml` / the generated `AppLocalizations.supportedLocales`.
  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  static const String _storageKey = 'locale_code';

  final FlutterSecureStorage _storage;
  final Logger _logger;

  /// Kept in step with the state so the data layer can pick `…Ar` / `…En` fields.
  final AppLanguage? _language;

  @override
  void onChange(Change<Locale> change) {
    super.onChange(change);
    _language?.code = change.nextState.languageCode;
  }

  Future<void> _restore() async {
    try {
      final code = await _storage.read(key: _storageKey);
      if (code == null) return;
      final restored = supportedLocales
          .where((l) => l.languageCode == code)
          .firstOrNull;
      if (restored != null && !isClosed && restored != state) {
        emit(restored);
      }
    } catch (e, st) {
      // Corrupt/unavailable secure storage must never crash startup — the
      // cubit simply keeps its default locale.
      _logger.w('Failed to restore persisted locale', error: e, stackTrace: st);
    }
  }

  /// Sets [locale] and persists it. No-ops for an unsupported locale or one
  /// matching the current state.
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale) || locale == state) return;
    emit(locale);
    try {
      await _storage.write(key: _storageKey, value: locale.languageCode);
    } catch (e, st) {
      _logger.w('Failed to persist locale', error: e, stackTrace: st);
    }
  }

  /// Switches between Arabic and English.
  Future<void> toggleLocale() => setLocale(
        state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'),
      );
}
