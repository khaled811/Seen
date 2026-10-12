import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/core/seen_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <String>[];

  setUp(() {
    platformCalls.clear();
    SeenHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        platformCalls.add(call.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    SeenHaptics.patternPlayer = null;
    SeenHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('a lap is a medium impact, undo/light a light one', () {
    SeenHaptics.lap();
    SeenHaptics.light();
    SeenHaptics.select();
    expect(platformCalls, [
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  test('completion plays the double-pulse pattern [0, 40, 60, 40]', () async {
    final patterns = <List<int>>[];
    SeenHaptics.patternPlayer = (p) async => patterns.add(p);
    SeenHaptics.complete();
    await Future<void>.delayed(Duration.zero);
    expect(patterns, [
      [0, 40, 60, 40],
    ]);
  });

  test('qibla lock and tasbeeh target use their own distinct patterns',
      () async {
    final patterns = <List<int>>[];
    SeenHaptics.patternPlayer = (p) async => patterns.add(p);
    SeenHaptics.lock();
    SeenHaptics.targetReached();
    await Future<void>.delayed(Duration.zero);
    expect(patterns, [
      [0, 30, 50, 30],
      [0, 60, 80, 60],
    ]);
  });

  test('lap and completion feel different', () async {
    final patterns = <List<int>>[];
    SeenHaptics.patternPlayer = (p) async => patterns.add(p);
    SeenHaptics.lap();
    SeenHaptics.complete();
    await Future<void>.delayed(Duration.zero);
    expect(platformCalls, ['HapticFeedbackType.mediumImpact']);
    expect(patterns, hasLength(1));
  });

  test('a failing vibration backend falls back to a heavy impact, not a crash',
      () async {
    SeenHaptics.patternPlayer = (_) async => throw StateError('no vibrator');
    SeenHaptics.complete();
    await Future<void>.delayed(Duration.zero);
    expect(platformCalls, contains('HapticFeedbackType.heavyImpact'));
  });

  test('the global switch silences everything', () async {
    final patterns = <List<int>>[];
    SeenHaptics.patternPlayer = (p) async => patterns.add(p);
    SeenHaptics.enabled = false;
    SeenHaptics.lap();
    SeenHaptics.select();
    SeenHaptics.complete();
    SeenHaptics.lock();
    await Future<void>.delayed(Duration.zero);
    expect(platformCalls, isEmpty);
    expect(patterns, isEmpty);
  });
}
