// A revealed sensitive value: one at a time, in memory only, hidden after 30 s, in the
// background and on dispose; a late answer for a hidden value is dropped.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/reveal/reveal_controller.dart';

void main() {
  late List<String> asked;
  late Map<String, Completer<String>> answers;
  late List<bool> secure;

  RevealController make({Duration duration = const Duration(seconds: 30)}) => RevealController(
        duration: duration,
        onSecureChanged: secure.add,
        fetch: (id) {
          asked.add(id);
          return (answers[id] ??= Completer<String>()).future;
        },
      );

  setUp(() {
    asked = [];
    answers = {};
    secure = [];
  });

  testWidgets('reveal shows the value, flags the screen secure, and hides it after 30 seconds', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    expect(c.isLoading('a'), isTrue);
    answers['a']!.complete('N08494821');
    await shown;
    expect(c.valueOf('a'), 'N08494821');
    expect(c.secondsLeft, 30);
    expect(secure, [true]);

    await tester.pump(const Duration(seconds: 29));
    expect(c.valueOf('a'), 'N08494821');
    expect(c.secondsLeft, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(c.valueOf('a'), isNull);
    expect(secure, [true, false]);
  });

  testWidgets('only one value at a time: revealing another hides the first', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final first = c.reveal('a');
    answers['a']!.complete('one');
    await first;
    final second = c.reveal('b');
    expect(c.valueOf('a'), isNull);
    answers['b']!.complete('two');
    await second;
    expect(c.valueOf('b'), 'two');
    expect(c.id, 'b');
    c.hide();
  });

  testWidgets('hide clears the value at once', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    answers['a']!.complete('one');
    await shown;
    c.hide();
    expect(c.valueOf('a'), isNull);
    expect(secure, [true, false]);
  });

  testWidgets('going to the background hides it', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    answers['a']!.complete('one');
    await shown;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(c.valueOf('a'), isNull);
  });

  testWidgets('an answer that arrives after the value was hidden is dropped', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    c.hide();
    answers['a']!.complete('late');
    await shown;
    expect(c.valueOf('a'), isNull);
    expect(secure, isEmpty);
  });

  testWidgets('a rate limit blocks further reveals until its time has passed', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    answers['a']!.completeError(RevealRateLimited(const Duration(minutes: 12)));
    await shown;
    expect(c.blockedFor, isNotNull);
    expect(c.valueOf('a'), isNull);
    await c.reveal('b');
    expect(asked, ['a'], reason: 'no request while blocked');
  });

  testWidgets('no permission is remembered and stops further reveals', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    answers['a']!.completeError(RevealForbidden());
    await shown;
    expect(c.forbidden, isTrue);
    await c.reveal('b');
    expect(asked, ['a']);
  });

  testWidgets('another failure is flagged without blocking a retry', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    answers['a']!.completeError(StateError('offline'));
    await shown;
    expect(c.failed, isTrue);
    expect(c.forbidden, isFalse);
    expect(c.blockedFor, isNull);
  });

  testWidgets('a second tap on the value being fetched asks nothing more', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    final shown = c.reveal('a');
    await c.reveal('a');
    expect(asked, ['a']);
    answers['a']!.complete('one');
    await shown;
    c.hide();
  });

  testWidgets('dispose clears the secure flag and never notifies afterwards', (tester) async {
    final c = make();
    final shown = c.reveal('a');
    answers['a']!.complete('one');
    await shown;
    c.dispose();
    expect(secure, [true, false]);
    await tester.pump(const Duration(seconds: 31)); // the timer is gone: nothing throws
  });

  testWidgets('dispose while a reveal is in flight drops its answer', (tester) async {
    final c = make();
    final shown = c.reveal('a');
    c.dispose();
    answers['a']!.complete('late');
    await shown;
    expect(secure, isEmpty);
  });
}
