import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tasbeeh.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/tasbeeh_cubit.dart';

import '../support/remembrance_fakes.dart';

Future<TasbeehCubit> _ready(TasbeehHarness h) async {
  final c = h.module.createCubit();
  await c.load();
  return c;
}

void main() {
  group('loading', () {
    test('first use: the first dhikr, target 33, zero', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      final p = c.state.progress!;
      expect(c.state.status, TasbeehStatus.ready);
      expect(p.dhikrId, 'one');
      expect(p.target, TasbeehTarget.thirtyThree);
      expect(p.count, 0);
      expect(c.state.dhikr!.label, 'ذكر أول');
      await c.close();
    });

    test('restores the saved count, dhikr and target after an app kill', () async {
      final h = TasbeehHarness();
      final saved = h.progress(
        dhikrId: 'two',
        target: TasbeehTarget.hundred,
        count: 41,
        daily: const {'two': DhikrDay(total: 141, rounds: 1)},
      );
      final h2 = TasbeehHarness(initial: saved);
      final c = await _ready(h2);
      expect(c.state.progress, saved);
      expect(c.state.dhikr!.id, 'two');
      await c.close();
    });

    test('a saved dhikr that no longer exists falls back to the first', () async {
      final h = TasbeehHarness();
      final h2 = TasbeehHarness(initial: h.progress(dhikrId: 'gone', count: 12));
      final c = await _ready(h2);
      expect(c.state.progress!.dhikrId, 'one');
      expect(c.state.progress!.count, 0, reason: 'the count belonged to another dhikr');
      await c.close();
    });

    test('an unreadable save starts fresh instead of failing', () async {
      final h = TasbeehHarness();
      h.repo.failLoad = true;
      final c = await _ready(h);
      expect(c.state.status, TasbeehStatus.ready);
      expect(c.state.progress!.count, 0);
      await c.close();
    });

    test('no adhkar at all is a failure state', () async {
      final h = TasbeehHarness(catalog: FakeDhikrCatalog(fail: true));
      final c = await _ready(h);
      expect(c.state.status, TasbeehStatus.failure);
      await c.close();
    });

    test('yesterday\'s totals are dropped when the screen opens', () async {
      final yesterday = TasbeehHarness(start: DateTime(2026, 10, 2, 20));
      final saved = yesterday.progress(
        count: 5,
        daily: const {'one': DhikrDay(total: 99, rounds: 3)},
      );
      final h = TasbeehHarness(initial: saved, start: DateTime(2026, 10, 3, 8));
      final c = await _ready(h);
      expect(c.state.progress!.today.total, 0);
      expect(c.state.progress!.count, 5, reason: 'the count in hand stays');
      expect(c.state.progress!.day, '2026-10-03');
      await c.close();
    });
  });

  group('counting', () {
    test('every tap changes the state and is persisted immediately', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.tap();
      expect(c.state.progress!.count, 1, reason: 'on screen in the same frame');
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.count, 1);
      c.tap();
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.count, 2);
      await c.close();
    });

    test('tap returns true only for the tap that completes the round', () async {
      final h = TasbeehHarness(
        initial: TasbeehHarness().progress(count: 31),
      );
      final c = await _ready(h);
      expect(c.tap(), isFalse, reason: '32');
      expect(c.tap(), isTrue, reason: '33 completes the round');
      expect(c.state.progress!.complete, isTrue);
      expect(c.tap(), isFalse, reason: 'the next round starts at 1');
      expect(c.state.progress!.count, 1);
      await c.close();
    });

    test('a full cycle of 33 then 100', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      var reached = 0;
      for (var i = 0; i < 33; i++) {
        if (c.tap()) reached++;
      }
      expect(reached, 1);
      expect(c.state.progress!.today.rounds, 1);

      c.selectTarget(TasbeehTarget.hundred);
      expect(c.state.progress!.complete, isFalse);
      for (var i = 0; i < 100; i++) {
        if (c.tap()) reached++;
      }
      expect(reached, 2);
      await c.close();
    });

    test('open mode never reports a completed round', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.selectTarget(TasbeehTarget.open);
      for (var i = 0; i < 150; i++) {
        expect(c.tap(), isFalse);
      }
      expect(c.state.progress!.count, 150);
      await c.close();
    });

    test('totals reset when the clock passes local midnight', () async {
      final h = TasbeehHarness(start: DateTime(2026, 10, 3, 23, 59, 58));
      final c = await _ready(h);
      c.tap();
      c.tap();
      expect(c.state.progress!.today.total, 2);
      h.clock.now = DateTime(2026, 10, 4, 0, 0, 3);
      c.tap();
      expect(c.state.progress!.today.total, 1);
      expect(c.state.progress!.count, 3);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.day, '2026-10-04');
      await c.close();
    });

    test('taps before the data is loaded are ignored', () async {
      final h = TasbeehHarness();
      final c = h.module.createCubit();
      expect(c.tap(), isFalse);
      expect(c.state.progress, isNull);
      await c.close();
    });
  });

  group('dhikr, target and reset', () {
    test('choosing another dhikr resets the count and persists', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      for (var i = 0; i < 10; i++) {
        c.tap();
      }
      c.selectDhikr('two');
      expect(c.state.progress!.dhikrId, 'two');
      expect(c.state.progress!.count, 0);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.dhikrId, 'two');
      await c.close();
    });

    test('an unknown dhikr id is ignored', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.tap();
      c.selectDhikr('nope');
      expect(c.state.progress!.dhikrId, 'one');
      expect(c.state.progress!.count, 1);
      await c.close();
    });

    test('the same dhikr again changes nothing and writes nothing', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.tap();
      await Future<void>.delayed(Duration.zero);
      final saves = h.repo.saves;
      c.selectDhikr('one');
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.saves, saves);
      await c.close();
    });

    test('changing the target is persisted', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.selectTarget(TasbeehTarget.open);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.target, TasbeehTarget.open);
      await c.close();
    });

    test('reset zeroes the count but keeps today\'s totals', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      for (var i = 0; i < 20; i++) {
        c.tap();
      }
      c.reset();
      expect(c.state.progress!.count, 0);
      expect(c.state.progress!.today.total, 20);
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.stored!.count, 0);
      await c.close();
    });

    test('reset at zero writes nothing', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      c.reset();
      await Future<void>.delayed(Duration.zero);
      expect(h.repo.saves, 0);
      await c.close();
    });
  });

  group('screen awake', () {
    test('held while open, released on close', () async {
      final h = TasbeehHarness();
      final c = await _ready(h);
      expect(h.awake.held, isTrue);
      await c.close();
      expect(h.awake.held, isFalse);
      expect(h.awake.releases, 1);
    });

    test('a cubit that never loaded releases nothing', () async {
      final h = TasbeehHarness();
      final c = h.module.createCubit();
      await c.close();
      expect(h.awake.releases, 0);
    });
  });

  group('storage failures', () {
    test('the count still advances and the user is told once', () async {
      final h = TasbeehHarness();
      h.repo.failSave = true;
      final c = await _ready(h);
      final seen = <bool>[];
      final sub = c.stream.listen((s) => seen.add(s.saveFailed));
      for (var i = 0; i < 5; i++) {
        c.tap();
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.state.progress!.count, 5);
      expect(c.state.saveFailed, isTrue);
      expect(seen.where((f) => f).length, greaterThanOrEqualTo(1));
      // The flag flips false -> true once, not on every failed tap.
      var flips = 0;
      for (var i = 1; i < seen.length; i++) {
        if (seen[i] && !seen[i - 1]) flips++;
      }
      expect(flips, 1);
      await sub.cancel();
      await c.close();
    });

    test('the warning clears once saving works again', () async {
      final h = TasbeehHarness();
      h.repo.failSave = true;
      final c = await _ready(h);
      c.tap();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.saveFailed, isTrue);
      h.repo.failSave = false;
      c.tap();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.saveFailed, isFalse);
      await c.close();
    });
  });
}
