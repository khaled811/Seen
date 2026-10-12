import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dashboard_snapshot.dart';
import 'package:seen_booking/features/spiritual/domain/entities/day_prayers.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_state.dart';

import '../support/fakes.dart';

class _FailingRepo implements DashboardRepository {
  int calls = 0;

  @override
  Future<Either<Failure, DashboardSnapshot>> load() async {
    calls++;
    return const Left(NetworkFailure('offline'));
  }
}

class _FlakyRepo implements DashboardRepository {
  _FlakyRepo(this.inner);

  final DashboardRepository inner;
  bool failNext = false;
  int calls = 0;

  @override
  Future<Either<Failure, DashboardSnapshot>> load() {
    calls++;
    if (failNext) {
      failNext = false;
      return Future.value(const Left(NetworkFailure('offline')));
    }
    return inner.load();
  }
}

void main() {
  late DateTime now;

  DashboardCubit build({
    DashboardRepository? repo,
    Duration tick = const Duration(hours: 1),
  }) =>
      DashboardCubit(
        GetDashboardUseCase(repo ?? MockDashboardRepository(clock: () => now)),
        clock: () => now,
        tickInterval: tick,
      );

  setUp(() => now = DateTime(2026, 10, 3, 11, 40));

  test('starts in the initial state', () async {
    final cubit = build();
    expect(cubit.state, const DashboardInitial());
    await cubit.close();
  });

  test('load emits loading then loaded with the derived next prayer', () async {
    final cubit = build();
    final states = <DashboardState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(states.first, const DashboardLoading());
    final loaded = states.last as DashboardLoaded;
    expect(loaded.next.slot, PrayerSlot.dhuhr);
    expect(loaded.next.remainingMinutes, 35);
    expect(loaded.snapshot.activeRite?.currentLap, 3);
    await sub.cancel();
    await cubit.close();
  });

  test('a repository failure becomes DashboardFailure', () async {
    final cubit = build(repo: _FailingRepo());
    await cubit.load();
    expect(cubit.state, const DashboardFailure('offline'));
    await cubit.close();
  });

  test('duplicate load requests while loading are dropped', () async {
    final repo = _FailingRepo();
    final cubit = build(repo: repo);
    final first = cubit.load();
    final second = cubit.load();
    await Future.wait([first, second]);
    expect(repo.calls, 1);
    await cubit.close();
  });

  test('refreshClock updates the countdown, and only when it changed', () async {
    final cubit = build();
    await cubit.load();
    final emitted = <DashboardState>[];
    final sub = cubit.stream.listen(emitted.add);

    cubit.refreshClock(); // same minute -> equal state -> no emission
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);

    now = DateTime(2026, 10, 3, 11, 41);
    cubit.refreshClock();
    await Future<void>.delayed(Duration.zero);
    expect((emitted.single as DashboardLoaded).next.remainingMinutes, 34);
    await sub.cancel();
    await cubit.close();
  });

  test('crossing a prayer time advances the next prayer', () async {
    final cubit = build();
    await cubit.load();
    now = DateTime(2026, 10, 3, 12, 16);
    cubit.refreshClock();
    expect((cubit.state as DashboardLoaded).next.slot, PrayerSlot.asr);
    await cubit.close();
  });

  test('the timer ticks while active and stops when paused or closed', () async {
    final cubit = build(tick: const Duration(milliseconds: 20));
    await cubit.load();

    now = DateTime(2026, 10, 3, 11, 50);
    await cubit.stream.first.timeout(const Duration(seconds: 2));
    expect((cubit.state as DashboardLoaded).next.remainingMinutes, 25);

    cubit.setActive(false);
    now = DateTime(2026, 10, 3, 12, 0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((cubit.state as DashboardLoaded).next.remainingMinutes, 25,
        reason: 'paused: no ticks');

    cubit.setActive(true); // refreshes immediately
    expect((cubit.state as DashboardLoaded).next.remainingMinutes, 15);

    await cubit.close();
    now = DateTime(2026, 10, 3, 12, 10);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((cubit.state as DashboardLoaded).next.remainingMinutes, 15,
        reason: 'closed: timer cancelled');
  });

  group('persisted rite', () {
    test('the dashboard shows the stored session, and none when absent',
        () async {
      final sessions = InMemoryTawafRepo();
      final repo = MockDashboardRepository(clock: () => now, sessions: sessions);
      var snapshot = (await repo.load()).getOrElse((_) => throw 'x');
      expect(snapshot.activeRite, isNull);

      sessions.stored = TawafSession.start(RiteMode.sai, now);
      snapshot = (await repo.load()).getOrElse((_) => throw 'x');
      expect(snapshot.activeRite?.mode, RiteMode.sai);
    });

    test('an unreadable session store does not break the dashboard', () async {
      final sessions = InMemoryTawafRepo()..failLoad = true;
      final repo = MockDashboardRepository(clock: () => now, sessions: sessions);
      final snapshot = (await repo.load()).getOrElse((_) => throw 'x');
      expect(snapshot.activeRite, isNull);
    });

    test('refresh picks up a changed session without a loading flash',
        () async {
      final sessions = InMemoryTawafRepo();
      final cubit = build(
        repo: MockDashboardRepository(clock: () => now, sessions: sessions),
      );
      await cubit.load();
      expect((cubit.state as DashboardLoaded).snapshot.activeRite, isNull);

      final states = <DashboardState>[];
      final sub = cubit.stream.listen(states.add);
      sessions.stored = TawafSession.start(RiteMode.tawaf, now);
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(states.whereType<DashboardLoading>(), isEmpty);
      expect((cubit.state as DashboardLoaded).snapshot.activeRite, isNotNull);
      await sub.cancel();
      await cubit.close();
    });

    test('a failed refresh keeps what is on screen', () async {
      final repo = _FlakyRepo(MockDashboardRepository(clock: () => now));
      final cubit = build(repo: repo);
      await cubit.load();
      final before = cubit.state;
      repo.failNext = true;
      await cubit.refresh();
      expect(cubit.state, before);
      expect(repo.calls, 2);
      await cubit.close();
    });
  });
}
