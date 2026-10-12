import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/reader_view_prefs.dart';
import '../../domain/repositories/reader_view_prefs_repository.dart';

/// Reading-style choice in `shared_preferences`. Unreadable storage falls back
/// to the defaults (list view) rather than blocking the reader.
class ReaderViewPrefsRepositoryImpl implements ReaderViewPrefsRepository {
  ReaderViewPrefsRepositoryImpl({Future<SharedPreferences>? preferences})
      : _injected = preferences;

  static const pagesKey = 'spiritual.quran.view_pages';

  final Future<SharedPreferences>? _injected;

  Future<SharedPreferences> get _preferences =>
      _injected ?? SharedPreferences.getInstance();

  @override
  Future<Either<Failure, ReaderViewPrefs>> load() async {
    try {
      final p = await _preferences;
      return Right(ReaderViewPrefs(pages: p.getBool(pagesKey) ?? false));
    } catch (e) {
      return Left(CacheFailure('Could not read reader view: $e'));
    }
  }

  @override
  Future<Either<Failure, ReaderViewPrefs>> save(ReaderViewPrefs prefs) async {
    try {
      final p = await _preferences;
      final ok = await p.setBool(pagesKey, prefs.pages);
      return ok
          ? Right(prefs)
          : const Left(CacheFailure('Could not save reader view'));
    } catch (e) {
      return Left(CacheFailure('Could not save reader view: $e'));
    }
  }
}
