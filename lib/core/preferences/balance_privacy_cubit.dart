import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// "Hide the balance by default" (Figma ACC-04): `true` = the balance card starts
/// masked. Persists like `LocaleCubit`; a storage failure keeps the default (shown)
/// and never blocks startup. Owns no disposable resource.
class BalancePrivacyCubit extends Cubit<bool> {
  BalancePrivacyCubit({FlutterSecureStorage? storage, Logger? logger})
      : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger(),
        super(false) {
    _restore();
  }

  static const String _storageKey = 'hide_balance_default';

  final FlutterSecureStorage _storage;
  final Logger _logger;

  Future<void> _restore() async {
    try {
      final v = await _storage.read(key: _storageKey);
      if (v == 'true' && !isClosed) {
        emit(true);
      }
    } catch (e, st) {
      _logger.w('Failed to restore the balance privacy preference', error: e, stackTrace: st);
    }
  }

  Future<void> setHidden(bool hidden) async {
    if (hidden == state) {
      return;
    }
    emit(hidden);
    try {
      await _storage.write(key: _storageKey, value: hidden.toString());
    } catch (e, st) {
      _logger.w('Failed to persist the balance privacy preference', error: e, stackTrace: st);
    }
  }
}
