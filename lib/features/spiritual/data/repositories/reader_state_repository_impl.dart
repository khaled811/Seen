import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/repositories/reader_state_repository.dart';

/// Bookmarks, last-read position and font size in `shared_preferences`.
///
/// State is cached in memory and every mutation is applied to the cache, then
/// written; writes are queued so two quick taps can never interleave. If a
/// write fails the cache is rolled back and a [CacheFailure] is returned.
class ReaderStateRepositoryImpl implements ReaderStateRepository {
  ReaderStateRepositoryImpl({Future<SharedPreferences>? preferences})
      : _injected = preferences;

  static const bookmarksKey = 'spiritual.quran.bookmarks';
  static const lastReadKey = 'spiritual.quran.last_read';
  static const fontStepKey = 'spiritual.quran.font_step';

  final Future<SharedPreferences>? _injected;

  /// Resolved on first use, so merely constructing the app-wide module never
  /// touches the platform plugin.
  Future<SharedPreferences> get _preferences =>
      _injected ?? SharedPreferences.getInstance();

  ReaderState? _cache;
  Future<void> _queue = Future.value();

  @override
  Future<Either<Failure, ReaderState>> load() => _enqueue(() async {
        final cached = _cache;
        if (cached != null) return Right(cached);
        final prefs = await _preferences;
        final state = ReaderState(
          bookmarks: _readBookmarks(prefs),
          lastRead: _readLastRead(prefs),
          fontStep: _readFontStep(prefs),
        );
        _cache = state;
        return Right(state);
      });

  @override
  Future<Either<Failure, ReaderState>> toggleBookmark(
    int surah,
    int ayah, {
    required DateTime now,
  }) =>
      _mutate(
        (s) {
          final exists = s.hasBookmark(surah, ayah);
          final list = exists
              ? s.bookmarks.where((b) => !b.isAt(surah, ayah)).toList()
              : [Bookmark(surah: surah, ayah: ayah, createdAt: now), ...s.bookmarks];
          // Newest first; a restored bookmark keeps its original position.
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ReaderState(
            bookmarks: list,
            lastRead: s.lastRead,
            fontStep: s.fontStep,
          );
        },
        (prefs, s) => prefs.setString(
          bookmarksKey,
          jsonEncode([
            for (final b in s.bookmarks)
              {
                's': b.surah,
                'a': b.ayah,
                't': b.createdAt.millisecondsSinceEpoch,
              },
          ]),
        ),
      );

  @override
  Future<Either<Failure, ReaderState>> saveLastRead(LastRead lastRead) =>
      _mutate(
        (s) => ReaderState(
          bookmarks: s.bookmarks,
          lastRead: lastRead,
          fontStep: s.fontStep,
        ),
        (prefs, s) =>
            prefs.setString(lastReadKey, '${lastRead.surah}:${lastRead.ayah}'),
      );

  @override
  Future<Either<Failure, ReaderState>> saveFontStep(int step) {
    final clamped = step.clamp(0, ReaderState.fontSizes.length - 1);
    return _mutate(
      (s) => ReaderState(
        bookmarks: s.bookmarks,
        lastRead: s.lastRead,
        fontStep: clamped,
      ),
      (prefs, s) => prefs.setInt(fontStepKey, clamped),
    );
  }

  Future<Either<Failure, ReaderState>> _mutate(
    ReaderState Function(ReaderState) change,
    Future<bool> Function(SharedPreferences, ReaderState) write,
  ) =>
      _enqueue(() async {
        try {
          final prefs = await _preferences;
          final before = _cache ??= ReaderState(
            bookmarks: _readBookmarks(prefs),
            lastRead: _readLastRead(prefs),
            fontStep: _readFontStep(prefs),
          );
          final after = change(before);
          final ok = await write(prefs, after);
          if (!ok) return const Left(CacheFailure('Could not save reader state'));
          _cache = after;
          return Right(after);
        } catch (e) {
          return Left(CacheFailure('Could not save reader state: $e'));
        }
      });

  /// Runs [job] after every previously queued job has finished.
  Future<Either<Failure, ReaderState>> _enqueue(
    Future<Either<Failure, ReaderState>> Function() job,
  ) {
    final result = _queue.then((_) async {
      try {
        return await job();
      } catch (e) {
        return Left<Failure, ReaderState>(
          CacheFailure('Could not read reader state: $e'),
        );
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  static List<Bookmark> _readBookmarks(SharedPreferences prefs) {
    final raw = prefs.getString(bookmarksKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list.cast<Map<String, Object?>>())
          Bookmark(
            surah: e['s']! as int,
            ayah: e['a']! as int,
            createdAt: DateTime.fromMillisecondsSinceEpoch(e['t']! as int),
          ),
      ];
    } catch (_) {
      // Unreadable list: it cannot be restored, start clean rather than
      // failing the reader on every launch.
      prefs.remove(bookmarksKey);
      return const [];
    }
  }

  static LastRead? _readLastRead(SharedPreferences prefs) {
    final raw = prefs.getString(lastReadKey);
    if (raw == null) return null;
    final parts = raw.split(':');
    final s = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final a = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (s == null || a == null || s < 1 || s > 114 || a < 1) return null;
    return LastRead(surah: s, ayah: a);
  }

  static int _readFontStep(SharedPreferences prefs) {
    final v = prefs.getInt(fontStepKey);
    if (v == null || v < 0 || v >= ReaderState.fontSizes.length) {
      return ReaderState.defaultFontStep;
    }
    return v;
  }
}
