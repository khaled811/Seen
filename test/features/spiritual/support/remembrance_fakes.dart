import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/di/dua_module.dart';
import 'package:seen_booking/features/spiritual/di/tasbeeh_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_filter.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_user_data.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tasbeeh.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/dua_repository.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/dua_user_data_repository.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/tasbeeh_repository.dart';
import 'package:seen_booking/features/spiritual/domain/services/dua_sharer.dart';
import 'package:seen_booking/features/spiritual/domain/utils/tasbeeh_math.dart';

import 'fakes.dart';

// Placeholder text only: real religious text lives in the bundled data files.
const sampleDuas = <Dua>[
  Dua(
    id: 'a',
    category: DuaCategory.safar,
    title: 'دعاء السفر التجريبي',
    text: 'نَصٌّ تَجْرِيبِيٌّ لِلسَّفَرِ',
    isQuranic: false,
    source: 'صحيح مسلم',
    note: 'يُقال عند الركوب',
    audioAsset: 'assets/audio/duas/mock_silence.wav',
    durationSec: 3,
    reviewed: true,
  ),
  Dua(
    id: 'b',
    category: DuaCategory.hajj,
    title: 'تلبية تجريبية',
    text: 'نص تلبية تجريبي',
    isQuranic: false,
    source: 'متفق عليه',
    audioAsset: 'assets/audio/duas/mock_silence.wav',
    durationSec: 3,
    reviewed: true,
  ),
  Dua(
    id: 'c',
    category: DuaCategory.adhkar,
    title: 'ذكر الصباح التجريبي',
    text: 'نص ذكر الصباح',
    isQuranic: false,
    source: 'صحيح البخاري',
    audioAsset: 'assets/audio/duas/mock_silence.wav',
    durationSec: 3,
    reviewed: true,
  ),
  Dua(
    id: 'd',
    category: DuaCategory.jawami,
    title: 'دعاء جامع تجريبي',
    text: 'نص دعاء جامع',
    isQuranic: false,
    source: 'سنن الترمذي',
    reviewed: false,
  ),
];

/// Serves [duas]; like the real repository it hides unreviewed entries
/// unless [includeUnreviewed].
class ListDuaRepository implements DuaRepository {
  ListDuaRepository(this.duas, {this.includeUnreviewed = true, this.fail = false});

  final List<Dua> duas;
  final bool includeUnreviewed;
  final bool fail;

  @override
  Future<Either<Failure, List<Dua>>> getDuas({DuaCategory? category}) async {
    if (fail) return const Left(CacheFailure('no duas'));
    return Right([
      for (final d in duas)
        if ((includeUnreviewed || d.reviewed) &&
            (category == null || d.category == category))
          d,
    ]);
  }
}

class InMemoryDuaUserData implements DuaUserDataRepository {
  InMemoryDuaUserData([this.data = const DuaUserData()]);

  DuaUserData data;
  bool failWrites = false;
  bool failLoad = false;
  int writes = 0;

  @override
  Future<Either<Failure, DuaUserData>> load() async =>
      failLoad ? const Left(CacheFailure('load failed')) : Right(data);

  @override
  Future<Either<Failure, DuaUserData>> toggleFavorite(String id) async {
    if (failWrites) return const Left(CacheFailure('disk full'));
    writes++;
    final next = {...data.favorites};
    if (!next.remove(id)) next.add(id);
    return Right(data = DuaUserData(favorites: next, filter: data.filter));
  }

  @override
  Future<Either<Failure, DuaUserData>> saveFilter(DuaFilter filter) async {
    if (failWrites) return const Left(CacheFailure('disk full'));
    writes++;
    return Right(data = DuaUserData(favorites: data.favorites, filter: filter));
  }
}

class FakeDuaSharer implements DuaSharer {
  final shared = <({String subject, String text})>[];
  bool succeeds = true;

  @override
  Future<bool> share({required String subject, required String text}) async {
    shared.add((subject: subject, text: text));
    return succeeds;
  }
}

class FakeClipboard implements TextClipboard {
  final copied = <String>[];
  bool throws = false;

  String? get last => copied.isEmpty ? null : copied.last;

  @override
  Future<void> copy(String text) async {
    if (throws) throw StateError('clipboard unavailable');
    copied.add(text);
  }
}

/// Everything the dua library needs, in memory.
class DuaHarness {
  DuaHarness({
    List<Dua> duas = sampleDuas,
    bool includeUnreviewed = true,
    DuaUserData initial = const DuaUserData(),
    bool failDuas = false,
  })  : repo = ListDuaRepository(
          duas,
          includeUnreviewed: includeUnreviewed,
          fail: failDuas,
        ),
        userData = InMemoryDuaUserData(initial) {
    module = DuaModule(
      duas: repo,
      userData: userData,
      sharer: sharer,
      clipboard: clipboard,
      player: player,
    );
  }

  final ListDuaRepository repo;
  final InMemoryDuaUserData userData;
  final sharer = FakeDuaSharer();
  final clipboard = FakeClipboard();
  final player = FakeAudioPlayer();
  late final DuaModule module;
}

const sampleAdhkar = <TasbeehDhikr>[
  TasbeehDhikr(id: 'one', label: 'ذكر أول'),
  TasbeehDhikr(id: 'two', label: 'ذكر ثان'),
  TasbeehDhikr(id: 'three', label: 'ذكر ثالث'),
];

class FakeDhikrCatalog implements DhikrCatalog {
  FakeDhikrCatalog({this.adhkarList = sampleAdhkar, this.fail = false});

  final List<TasbeehDhikr> adhkarList;
  final bool fail;

  @override
  Future<Either<Failure, List<TasbeehDhikr>>> adhkar() async =>
      fail ? const Left(CacheFailure('no adhkar')) : Right(adhkarList);
}

class InMemoryTasbeehRepo implements TasbeehRepository {
  InMemoryTasbeehRepo([this.stored]);

  TasbeehProgress? stored;
  bool failSave = false;
  bool failLoad = false;
  int saves = 0;

  @override
  Future<Either<Failure, TasbeehProgress?>> load() async =>
      failLoad ? const Left(CacheFailure('load failed')) : Right(stored);

  @override
  Future<Either<Failure, Unit>> save(TasbeehProgress progress) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    saves++;
    stored = progress;
    return const Right(unit);
  }
}

/// Everything the tasbeeh needs, in memory.
class TasbeehHarness {
  TasbeehHarness({TasbeehProgress? initial, DateTime? start, FakeDhikrCatalog? catalog})
      : clock = FakeClock(start ?? DateTime(2026, 10, 3, 14)),
        repo = InMemoryTasbeehRepo(initial) {
    module = TasbeehModule(
      catalog: catalog ?? FakeDhikrCatalog(),
      repository: repo,
      screenAwake: awake,
      clock: clock.call,
    );
  }

  final FakeClock clock;
  final InMemoryTasbeehRepo repo;
  final awake = FakeScreenAwake();
  late final TasbeehModule module;

  /// A saved progress for the harness's day.
  TasbeehProgress progress({
    String dhikrId = 'one',
    TasbeehTarget target = TasbeehTarget.thirtyThree,
    int count = 0,
    bool complete = false,
    Map<String, DhikrDay> daily = const {},
  }) =>
      TasbeehProgress(
        dhikrId: dhikrId,
        target: target,
        count: count,
        complete: complete,
        day: TasbeehMath.dayKey(clock.now),
        daily: daily,
      );
}
