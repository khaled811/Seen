import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/domain/entities/bookmark.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/domain/entities/last_read.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_view_prefs.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/reader_view_prefs_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/dua_repository.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/reader_state_repository.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/tawaf_session_repository.dart';
import 'package:seen_booking/features/spiritual/domain/services/dua_audio_player.dart';
import 'package:seen_booking/features/spiritual/domain/services/screen_awake.dart';

/// In-memory [TawafSessionRepository] that can be told to fail.
class InMemoryTawafRepo implements TawafSessionRepository {
  InMemoryTawafRepo([this.stored]);

  TawafSession? stored;
  bool failSave = false;
  bool failLoad = false;
  bool failClear = false;
  int saves = 0;
  int clears = 0;

  @override
  Future<Either<Failure, TawafSession?>> load() async =>
      failLoad ? const Left(CacheFailure('load failed')) : Right(stored);

  @override
  Future<Either<Failure, Unit>> save(TawafSession session) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    saves++;
    stored = session;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    if (failClear) return const Left(CacheFailure('clear failed'));
    clears++;
    stored = null;
    return const Right(unit);
  }
}

class FakeScreenAwake implements ScreenAwake {
  int holds = 0;
  int releases = 0;

  bool get held => holds > releases;

  void reset() {
    holds = 0;
    releases = 0;
  }

  @override
  Future<void> hold() async => holds++;

  @override
  Future<void> release() async => releases++;
}

class FakeAudioPlayer implements DuaAudioPlayer {
  final _controller = StreamController<DuaPlayback>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final played = <String>[];
  int stops = 0;
  bool failPlay = false;

  @override
  Stream<DuaPlayback> get states => _controller.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  /// Simulates playback progress.
  void position(Duration d) => _positions.add(d);

  @override
  Future<void> play(String asset) async {
    if (failPlay) throw StateError('missing asset');
    played.add(asset);
    _controller.add(DuaPlayback.playing);
  }

  @override
  Future<void> stop() async {
    stops++;
    _controller.add(DuaPlayback.idle);
  }

  /// Simulates the clip finishing on its own.
  void finish() => _controller.add(DuaPlayback.idle);
}

class FakeDuaRepository implements DuaRepository {
  FakeDuaRepository({this.fail = false});

  final bool fail;

  static const rukn = Dua(
    id: 'rukn',
    category: DuaCategory.hajj,
    title: 'بين الركن اليماني والحجر الأسود',
    text: 'دعاء الطواف التجريبي',
    isQuranic: true,
    source: 'مصدر',
    audioAsset: 'assets/audio/duas/mock_silence.wav',
    reviewed: false,
  );
  static const safaMarwa = Dua(
    id: 'safa-marwa',
    category: DuaCategory.hajj,
    title: 'عند الصعود على الصفا والمروة',
    text: 'دعاء السعي التجريبي',
    isQuranic: false,
    source: 'مصدر',
    audioAsset: 'assets/audio/duas/mock_silence.wav',
    reviewed: false,
  );

  @override
  Future<Either<Failure, List<Dua>>> getDuas({DuaCategory? category}) async =>
      fail
          ? const Left(CacheFailure('no duas'))
          : const Right([rukn, safaMarwa]);
}

/// A clock the test advances by hand.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 10, 3, 14);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

/// In-memory reader state with failure switches, mirroring the real
/// repository's semantics (newest bookmark first, clamped font step).
class InMemoryReaderState implements ReaderStateRepository {
  InMemoryReaderState([ReaderState? initial]) : state = initial ?? const ReaderState();

  ReaderState state;
  bool failWrites = false;
  int toggles = 0;
  int lastReadSaves = 0;

  @override
  Future<Either<Failure, ReaderState>> load() async => Right(state);

  @override
  Future<Either<Failure, ReaderState>> toggleBookmark(
    int surah,
    int ayah, {
    required DateTime now,
  }) async {
    if (failWrites) return const Left(CacheFailure('disk full'));
    toggles++;
    final exists = state.hasBookmark(surah, ayah);
    final list = exists
        ? state.bookmarks.where((b) => !b.isAt(surah, ayah)).toList()
        : [Bookmark(surah: surah, ayah: ayah, createdAt: now), ...state.bookmarks];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = ReaderState(bookmarks: list, lastRead: state.lastRead, fontStep: state.fontStep);
    return Right(state);
  }

  @override
  Future<Either<Failure, ReaderState>> saveLastRead(LastRead lastRead) async {
    if (failWrites) return const Left(CacheFailure('disk full'));
    lastReadSaves++;
    state = ReaderState(bookmarks: state.bookmarks, lastRead: lastRead, fontStep: state.fontStep);
    return Right(state);
  }

  @override
  Future<Either<Failure, ReaderState>> saveFontStep(int step) async {
    if (failWrites) return const Left(CacheFailure('disk full'));
    state = ReaderState(
      bookmarks: state.bookmarks,
      lastRead: state.lastRead,
      fontStep: step.clamp(0, ReaderState.fontSizes.length - 1),
    );
    return Right(state);
  }
}


/// In-memory reader view choice (list or pages, night or paper).
class InMemoryViewPrefs implements ReaderViewPrefsRepository {
  InMemoryViewPrefs([this.prefs = const ReaderViewPrefs()]);

  ReaderViewPrefs prefs;
  bool failSave = false;

  @override
  Future<Either<Failure, ReaderViewPrefs>> load() async => Right(prefs);

  @override
  Future<Either<Failure, ReaderViewPrefs>> save(ReaderViewPrefs next) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    return Right(prefs = next);
  }
}
