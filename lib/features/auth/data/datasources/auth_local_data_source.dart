import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/storage_keys.dart';
import '../models/auth_user_dto.dart';

/// Local (secure-storage) persistence for the auth session.
abstract interface class AuthLocalDataSource {
  Future<void> saveSession({
    required String accessToken,
    required AuthUserDto user,
  });

  Future<String?> readToken();

  Future<AuthUserDto?> readUser();

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({FlutterSecureStorage? secureStorage, Logger? logger})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger();

  final FlutterSecureStorage _secureStorage;
  final Logger _logger;

  @override
  Future<void> saveSession({
    required String accessToken,
    required AuthUserDto user,
  }) {
    return Future.wait([
      _secureStorage.write(key: StorageKeys.authToken, value: accessToken),
      _secureStorage.write(
        key: StorageKeys.sessionUser,
        value: jsonEncode(user.toJson()),
      ),
    ]);
  }

  @override
  Future<String?> readToken() async {
    try {
      return await _secureStorage.read(key: StorageKeys.authToken);
    } catch (e, st) {
      // No secure storage backend available (or a genuine keystore failure)
      // must never crash session restore — treat it as "no session".
      _logger.w('Failed to read persisted auth token', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<AuthUserDto?> readUser() async {
    try {
      final raw = await _secureStorage.read(key: StorageKeys.sessionUser);
      if (raw == null) return null;
      return AuthUserDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      // An unreadable store or a corrupt cached value must never crash
      // session restore — treat it as "no session" and fall back to sign-in.
      _logger.w('Failed to read cached session', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> clear() => Future.wait([
        _secureStorage.delete(key: StorageKeys.authToken),
        _secureStorage.delete(key: StorageKeys.sessionUser),
      ]);
}
