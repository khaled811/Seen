import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/dua_filter.dart';
import '../../domain/entities/dua_user_data.dart';
import '../../domain/repositories/dua_user_data_repository.dart';

/// Saved duas and the last chip in `shared_preferences`.
///
/// Same scheme as the reader state: cached in memory, mutations applied to
/// the cache and written through a queue so two quick taps never interleave;
/// a failed write leaves the cache untouched and reports a [CacheFailure].
class DuaUserDataRepositoryImpl implements DuaUserDataRepository {
  DuaUserDataRepositoryImpl({Future<SharedPreferences>? preferences})
      : _injected = preferences;

  static const favoritesKey = 'spiritual.duas.favorites';
  static const filterKey = 'spiritual.duas.filter';

  final Future<SharedPreferences>? _injected;

  /// Resolved on first use, so constructing the module never touches the
  /// platform plugin.
  Future<SharedPreferences> get _preferences =>
      _injected ?? SharedPreferences.getInstance();

  DuaUserData? _cache;
  Future<void> _queue = Future.value();

  @override
  Future<Either<Failure, DuaUserData>> load() =>
      _run((prefs, current) async => Right(current));

  @override
  Future<Either<Failure, DuaUserData>> toggleFavorite(String id) =>
      _run((prefs, current) async {
        final next = {...current.favorites};
        if (!next.remove(id)) next.add(id);
        final ok = await prefs.setString(favoritesKey, jsonEncode(next.toList()));
        if (!ok) return const Left(CacheFailure('Could not save favourites'));
        return Right(DuaUserData(favorites: next, filter: current.filter));
      });

  @override
  Future<Either<Failure, DuaUserData>> saveFilter(DuaFilter filter) =>
      _run((prefs, current) async {
        final ok = await prefs.setString(filterKey, filter.name);
        if (!ok) return const Left(CacheFailure('Could not save filter'));
        return Right(DuaUserData(favorites: current.favorites, filter: filter));
      });

  Future<Either<Failure, DuaUserData>> _run(
    Future<Either<Failure, DuaUserData>> Function(
      SharedPreferences prefs,
      DuaUserData current,
    ) job,
  ) {
    final result = _queue.then((_) async {
      try {
        final prefs = await _preferences;
        final current = _cache ??= _read(prefs);
        final out = await job(prefs, current);
        out.map((data) => _cache = data);
        return out;
      } catch (e) {
        return Left<Failure, DuaUserData>(
          CacheFailure('Could not use dua data: $e'),
        );
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  static DuaUserData _read(SharedPreferences prefs) {
    var favorites = <String>{};
    final raw = prefs.getString(favoritesKey);
    if (raw != null) {
      try {
        favorites = {for (final id in jsonDecode(raw) as List) id as String};
      } catch (_) {
        // An unreadable list cannot be restored; start clean instead of
        // failing the library on every launch.
        prefs.remove(favoritesKey);
      }
    }
    final name = prefs.getString(filterKey);
    final filter = DuaFilter.values.firstWhere(
      (f) => f.name == name,
      orElse: () => DuaFilter.all,
    );
    return DuaUserData(favorites: favorites, filter: filter);
  }
}
