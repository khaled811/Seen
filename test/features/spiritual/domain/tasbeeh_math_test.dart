import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tasbeeh.dart';
import 'package:seen_booking/features/spiritual/domain/utils/tasbeeh_math.dart';

final _noon = DateTime(2026, 10, 3, 12);

TasbeehProgress _p({
  String dhikr = 'a',
  TasbeehTarget target = TasbeehTarget.thirtyThree,
  int count = 0,
  bool complete = false,
  Map<String, DhikrDay> daily = const {},
  String? day,
}) =>
    TasbeehProgress(
      dhikrId: dhikr,
      target: target,
      count: count,
      complete: complete,
      day: day ?? TasbeehMath.dayKey(_noon),
      daily: daily,
    );

TasbeehProgress _tapTimes(TasbeehProgress p, int n, [DateTime? now]) {
  for (var i = 0; i < n; i++) {
    p = TasbeehMath.tap(p, now ?? _noon);
  }
  return p;
}

void main() {
  group('tap', () {
    test('counts one at a time and tallies the day', () {
      final p = _tapTimes(_p(), 5);
      expect(p.count, 5);
      expect(p.complete, isFalse);
      expect(p.today.total, 5);
      expect(p.today.rounds, 0);
    });

    test('the tap that reaches the target completes the round', () {
      final p = _tapTimes(_p(), 33);
      expect(p.count, 33);
      expect(p.complete, isTrue);
      expect(p.today.rounds, 1);
      expect(p.today.total, 33);
    });

    test('32 taps are not yet complete', () {
      expect(_tapTimes(_p(), 32).complete, isFalse);
    });

    test('rollover: the tap after a finished round starts the next at 1', () {
      final done = _tapTimes(_p(), 33);
      final next = TasbeehMath.tap(done, _noon);
      expect(next.count, 1, reason: 'never 0 and never 34');
      expect(next.complete, isFalse);
      expect(next.today.rounds, 1);
      expect(next.today.total, 34, reason: 'the tap still counts for the day');
    });

    test('three full rounds of 33 make 99 counts and 3 rounds', () {
      final p = _tapTimes(_p(), 99);
      expect(p.today.total, 99);
      expect(p.today.rounds, 3);
      expect(p.count, 33);
      expect(p.complete, isTrue);
    });

    test('100 target: completes exactly at 100', () {
      final p = _tapTimes(_p(target: TasbeehTarget.hundred), 99);
      expect(p.complete, isFalse);
      final done = TasbeehMath.tap(p, _noon);
      expect(done.complete, isTrue);
      expect(done.count, 100);
    });

    test('open mode never completes and keeps counting', () {
      final p = _tapTimes(_p(target: TasbeehTarget.open), 250);
      expect(p.count, 250);
      expect(p.complete, isFalse);
      expect(p.today.rounds, 0);
      expect(p.today.total, 250);
    });

    test('tallies are per dhikr', () {
      var p = _tapTimes(_p(dhikr: 'a'), 3);
      p = TasbeehMath.selectDhikr(p, 'b', _noon);
      p = _tapTimes(p, 2);
      expect(p.daily['a']!.total, 3);
      expect(p.daily['b']!.total, 2);
      expect(p.today.total, 2);
    });

    test('is pure: the input is not mutated', () {
      final before = _p();
      TasbeehMath.tap(before, _noon);
      expect(before.count, 0);
      expect(before.daily, isEmpty);
    });
  });

  group('daily totals', () {
    test('reset at local midnight, the count in hand is kept', () {
      final evening = DateTime(2026, 10, 3, 23, 59, 59);
      var p = _tapTimes(_p(day: TasbeehMath.dayKey(evening)), 10, evening);
      expect(p.today.total, 10);
      final after = DateTime(2026, 10, 4, 0, 0, 1);
      p = TasbeehMath.tap(p, after);
      expect(p.day, '2026-10-04');
      expect(p.count, 11, reason: 'a round may straddle midnight');
      expect(p.today.total, 1, reason: 'yesterday is gone');
      expect(p.today.rounds, 0);
    });

    test('the same day keeps accumulating', () {
      var p = _tapTimes(_p(), 3, DateTime(2026, 10, 3, 8));
      p = _tapTimes(p, 3, DateTime(2026, 10, 3, 22));
      expect(p.today.total, 6);
    });

    test('rollDay on a new day clears every dhikr, not just the active one', () {
      final p = _p(
        daily: const {'a': DhikrDay(total: 5), 'b': DhikrDay(total: 9, rounds: 2)},
        day: '2026-10-02',
      );
      final r = TasbeehMath.rollDay(p, _noon);
      expect(r.daily, isEmpty);
      expect(r.day, '2026-10-03');
    });

    test('dayKey pads month and day and uses the local calendar', () {
      expect(TasbeehMath.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(TasbeehMath.dayKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });
  });

  group('reset, dhikr and target', () {
    test('reset zeroes the count and the finished flag, keeps the tallies', () {
      final p = TasbeehMath.reset(_tapTimes(_p(), 33));
      expect(p.count, 0);
      expect(p.complete, isFalse);
      expect(p.today.total, 33);
      expect(p.today.rounds, 1);
    });

    test('a new dhikr starts from zero', () {
      final p = TasbeehMath.selectDhikr(_tapTimes(_p(), 12), 'b', _noon);
      expect(p.dhikrId, 'b');
      expect(p.count, 0);
    });

    test('picking the current dhikr changes nothing', () {
      final before = _tapTimes(_p(), 12);
      expect(TasbeehMath.selectDhikr(before, 'a', _noon), before);
    });

    test('a target the count already reached completes the round', () {
      final p = TasbeehMath.selectTarget(
        _p(target: TasbeehTarget.open, count: 40),
        TasbeehTarget.thirtyThree,
      );
      expect(p.complete, isTrue);
      expect(TasbeehMath.tap(p, _noon).count, 1);
    });

    test('a bigger target clears a finished round', () {
      final done = _tapTimes(_p(), 33);
      final p = TasbeehMath.selectTarget(done, TasbeehTarget.hundred);
      expect(p.complete, isFalse);
      expect(p.count, 33);
    });

    test('open clears the finished flag', () {
      final p = TasbeehMath.selectTarget(_tapTimes(_p(), 33), TasbeehTarget.open);
      expect(p.complete, isFalse);
    });
  });

  group('ring value', () {
    test('progress to the target, clamped to 1', () {
      expect(TasbeehMath.ringValue(_p(count: 0)), 0);
      expect(TasbeehMath.ringValue(_p(count: 11)), closeTo(1 / 3, 1e-9));
      expect(TasbeehMath.ringValue(_p(count: 33)), 1);
      expect(TasbeehMath.ringValue(_p(count: 50)), 1);
    });

    test('open mode shows progress within each block of 100', () {
      const open = TasbeehTarget.open;
      expect(TasbeehMath.ringValue(_p(target: open, count: 25)), 0.25);
      expect(TasbeehMath.ringValue(_p(target: open, count: 100)), 0);
      expect(TasbeehMath.ringValue(_p(target: open, count: 175)), 0.75);
    });
  });

  test('TasbeehTarget.fromValue round-trips and rejects unknowns', () {
    for (final t in TasbeehTarget.values) {
      expect(TasbeehTarget.fromValue(t.value), t);
    }
    expect(TasbeehTarget.fromValue(7), isNull);
    expect(TasbeehTarget.fromValue(null), isNull);
  });
}
