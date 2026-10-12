import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/tawaf_session.dart';
import '../../domain/repositories/tawaf_session_repository.dart';
import '../models/tawaf_session_dto.dart';

/// Persists the active session as JSON in `shared_preferences`. Every
/// [save] is awaited by the caller, so a lap is on disk before the UI
/// moves on.
class TawafSessionRepositoryImpl implements TawafSessionRepository {
  TawafSessionRepositoryImpl({Future<SharedPreferences>? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance();

  static const storageKey = 'spiritual.tawaf_session';

  final Future<SharedPreferences> _preferences;

  @override
  Future<Either<Failure, TawafSession?>> load() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(storageKey);
      if (raw == null) return const Right(null);
      try {
        return Right(TawafSessionDto.fromJson(jsonDecode(raw)).toEntity());
      } on FormatException {
        // Unreadable/corrupt record: it can never be restored, so drop it
        // rather than failing every launch. The user simply starts again.
        await prefs.remove(storageKey);
        return const Right(null);
      }
    } catch (e) {
      return Left(CacheFailure('Could not read the saved session: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> save(TawafSession session) async {
    try {
      final json = jsonEncode(TawafSessionDto.fromEntity(session).toJson());
      final ok = await (await _preferences).setString(storageKey, json);
      return ok
          ? const Right(unit)
          : const Left(CacheFailure('The session could not be saved'));
    } catch (e) {
      return Left(CacheFailure('Could not save the session: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    try {
      await (await _preferences).remove(storageKey);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Could not clear the session: $e'));
    }
  }
}
