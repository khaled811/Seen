import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/tasbeeh.dart';
import '../../domain/repositories/tasbeeh_repository.dart';

/// Tasbeeh progress in `shared_preferences`, as one JSON value.
///
/// A tap persists immediately, but a fast tapper must not queue hundreds of
/// disk writes: while a write is in flight only the latest progress is kept
/// and written as soon as the current write finishes. Every caller's future
/// completes once a write that includes its progress (or a newer one) landed.
class TasbeehRepositoryImpl implements TasbeehRepository {
  TasbeehRepositoryImpl({Future<SharedPreferences>? preferences})
      : _injected = preferences;

  static const key = 'spiritual.tasbeeh.v1';

  final Future<SharedPreferences>? _injected;

  Future<SharedPreferences> get _preferences =>
      _injected ?? SharedPreferences.getInstance();

  TasbeehProgress? _pending;
  List<Completer<Either<Failure, Unit>>> _waiting = [];
  bool _writing = false;

  @override
  Future<Either<Failure, TasbeehProgress?>> load() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(key);
      if (raw == null) return const Right(null);
      return Right(_decode(raw));
    } catch (e) {
      return Left(CacheFailure('Could not read tasbeeh: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> save(TasbeehProgress progress) {
    final done = Completer<Either<Failure, Unit>>();
    _pending = progress;
    _waiting.add(done);
    if (!_writing) unawaited(_drain());
    return done.future;
  }

  Future<void> _drain() async {
    _writing = true;
    while (_pending != null) {
      final progress = _pending!;
      final waiting = _waiting;
      _pending = null;
      _waiting = [];
      Either<Failure, Unit> result;
      try {
        final prefs = await _preferences;
        final ok = await prefs.setString(key, _encode(progress));
        result = ok
            ? const Right(unit)
            : const Left(CacheFailure('Could not save tasbeeh'));
      } catch (e) {
        result = Left(CacheFailure('Could not save tasbeeh: $e'));
      }
      for (final c in waiting) {
        c.complete(result);
      }
    }
    _writing = false;
  }

  static String _encode(TasbeehProgress p) => jsonEncode({
        'd': p.dhikrId,
        't': p.target.value,
        'c': p.count,
        'k': p.complete,
        'day': p.day,
        'daily': {
          for (final e in p.daily.entries)
            e.key: {'t': e.value.total, 'r': e.value.rounds},
        },
      });

  /// Forgiving: an unreadable value is ignored (null, a fresh start) rather
  /// than breaking the screen on every launch.
  static TasbeehProgress? _decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      final target = TasbeehTarget.fromValue(m['t'] as int?);
      final count = m['c'] as int?;
      final dhikr = m['d'] as String?;
      final day = m['day'] as String?;
      if (target == null ||
          count == null ||
          count < 0 ||
          dhikr == null ||
          day == null) {
        return null;
      }
      final stored = (m['daily'] as Map<String, Object?>?) ?? const {};
      final daily = <String, DhikrDay>{
        for (final e in stored.entries)
          e.key: DhikrDay(
            total: ((e.value! as Map)['t'] as int?) ?? 0,
            rounds: ((e.value! as Map)['r'] as int?) ?? 0,
          ),
      };
      return TasbeehProgress(
        dhikrId: dhikr,
        target: target,
        count: count,
        complete: m['k'] as bool? ?? false,
        day: day,
        daily: daily,
      );
    } catch (_) {
      return null;
    }
  }
}
