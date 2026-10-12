import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/core/arabic_digits.dart';
import 'package:seen_booking/features/spiritual/core/number_format.dart';
import 'package:seen_booking/features/spiritual/core/seen_haptics.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/utils/angles.dart';
import 'package:seen_booking/features/spiritual/domain/utils/qibla_math.dart';
import 'package:seen_booking/features/spiritual/presentation/qibla/compass_dial.dart';
import 'package:seen_booking/features/spiritual/presentation/qibla/qibla_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/kaaba_glyph.dart';

import '../support/prayer_fakes.dart';
import '../support/quran_harness.dart' show disposeTree, loadHub, pumpHub;

const _riyadh = LocationFound(24.7136, 46.6753);
final _bearing = QiblaMath.bearing(24.7136, 46.6753); // ≈ 244.6
final _bearingAr = toArabicDigits(_bearing.round());

/// Noon in Makkah, in UTC: the sun is up whatever the machine's time zone.
final _noonUtc = DateTime.utc(2026, 10, 3, 9);

PrayerHarness _harness({LocationFix fix = _riyadh, FakeCompassSensor? compass}) =>
    PrayerHarness(fix: fix, now: _noonUtc, compass: compass);

Future<void> _pump(
  WidgetTester tester,
  PrayerHarness h, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) =>
    pumpHub(
      tester,
      QiblaScreen(module: h.module),
      textScale: textScale,
      size: size,
    );

/// Pushes a heading and lets the cubit and the dial's ticker catch up.
Future<void> _heading(
  WidgetTester tester,
  PrayerHarness h,
  double deg, {
  int samples = 1,
  double? accuracy = 15,
}) async {
  for (var i = 0; i < samples; i++) {
    h.compass.emit(deg, accuracy: accuracy);
    await tester.pump(const Duration(milliseconds: 16));
  }
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The dial's current rotation as a compass heading (0..360).
double _dialHeading(WidgetTester tester) {
  final transform = tester
      .widgetList<Transform>(find.descendant(
        of: find.byType(CompassDial),
        matching: find.byType(Transform),
      ))
      .first;
  final m = transform.transform;
  final angle = math.atan2(m.entry(1, 0), m.entry(0, 0));
  return normalizeDegrees(-angle * 180 / math.pi);
}

Finder _pill(String text) => find.text(text);

void main() {
  final patterns = <List<int>>[];

  setUp(() {
    patterns.clear();
    SeenHaptics.patternPlayer = (p) async => patterns.add(p);
  });
  tearDown(() => SeenHaptics.patternPlayer = null);

  group('searching', () {
    testWidgets('shows the location, angle, heading, distance and Kaaba card',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, _bearing - 30);
      expect(find.text(SpiritualStrings.qiblaTitle), findsOneWidget);
      expect(find.text('موقعك الحالي'), findsOneWidget);
      expect(find.text('$_bearingAr°'), findsOneWidget, reason: 'Qibla angle');
      expect(
        find.text('اتجاهك ${toArabicDigits((_bearing - 30).round())}°'),
        findsOneWidget,
      );
      expect(find.text(SpiritualStrings.qiblaAngle), findsOneWidget);
      expect(find.text(formatThousands(QiblaMath.distanceKm(24.7136, 46.6753))),
          findsOneWidget);
      expect(find.text(SpiritualStrings.kmUnit), findsOneWidget);
      expect(find.text(SpiritualStrings.kaabaName), findsOneWidget);
      expect(find.text('٢١٫٤٢٢٥° ش · ٣٩٫٨٢٦٢° ق'), findsOneWidget);
      expect(find.text(SpiritualStrings.qiblaTip), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('waits for the first reading', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      expect(_pill(SpiritualStrings.waitingCompass), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('tells you which way to turn, and by how much', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, _bearing - 30);
      expect(_pill('استدر يمينًا ٣٠°'), findsOneWidget);
      await _heading(tester, h, _bearing + 45, samples: 60);
      expect(_pill('استدر يسارًا ٤٥°'), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the wrap-around case: heading 350°, Qibla 10° -> turn right 20°',
        (tester) async {
      final h = PrayerHarness(
        fix: const LocationFound(2, 39.8262), // Qibla ≈ 0°
        now: _noonUtc,
      );
      await _pump(tester, h);
      await _heading(tester, h, 350);
      expect(find.textContaining('استدر يمينًا'), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the dial\'s accessible label says where the Qibla is',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 200);
      expect(
        find.bySemanticsLabel(
          'بوصلة: القبلة على زاوية $_bearingAr درجة، واتجاهك الحالي ٢٠٠ درجة',
        ),
        findsOneWidget,
      );
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('dial rotation', () {
    testWidgets('rotates by minus the heading', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 90);
      expect(_dialHeading(tester), closeTo(90, 0.5));
      await _heading(tester, h, 90, samples: 80);
      expect(_dialHeading(tester), closeTo(90, 0.1));
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('crossing north takes the short way, never through 180°',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 355, samples: 3);
      final seen = <double>[];
      for (var i = 0; i < 40; i++) {
        h.compass.emit(5);
        await tester.pump(const Duration(milliseconds: 16));
        seen.add(_dialHeading(tester));
      }
      for (final v in seen) {
        expect(shortestDelta(0, v).abs(), lessThan(12),
            reason: 'stayed around north, got $v');
      }
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('it follows the sensor smoothly, not in one jump', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      h.compass.emit(160);
      final before = _dialHeading(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final mid = _dialHeading(tester);
      expect(shortestDelta(before, mid).abs(), greaterThan(0));
      expect(shortestDelta(mid, 160).abs(), greaterThan(0.5),
          reason: 'not there yet after two frames');
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('an idle compass asks for no frames (battery)', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      await _heading(tester, h, 100, samples: 80);
      // Nothing is animating: the tree settles instead of timing out.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the Kaaba glyph stays upright whatever the heading',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      for (final deg in [0.0, 70.0, 200.0, 310.0]) {
        await _heading(tester, h, deg, samples: 60);
        // Net rotation applied to the glyph: every Transform above it.
        var total = 0.0;
        for (final e in find
            .ancestor(of: find.byType(KaabaGlyph), matching: find.byType(Transform))
            .evaluate()) {
          final m = (e.widget as Transform).transform;
          total += math.atan2(m.entry(1, 0), m.entry(0, 0));
        }
        // Only the dial's own (−heading) and the placement/counter pair remain;
        // total rotation of the glyph is 0 modulo 360°.
        expect(
          shortestDelta(0, total * 180 / math.pi).abs(),
          lessThan(0.5),
          reason: 'heading $deg',
        );
      }
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('lock feedback', () {
    testWidgets('facing the Qibla: green state, pulse, ONE haptic',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, _bearing + 10);
      expect(patterns, isEmpty);
      for (var i = 0; i < 40; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_pill(SpiritualStrings.facingQibla), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_PulseRing'),
        findsOneWidget,
      );
      expect(patterns, [SeenHaptics.qiblaLockPattern]);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('wobbling inside the dead band does not buzz again',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      for (var i = 0; i < 50; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(patterns, hasLength(1));
      for (var i = 0; i < 40; i++) {
        h.compass.emit(_bearing + (i.isEven ? 3 : -3));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(patterns, hasLength(1));
      expect(_pill(SpiritualStrings.facingQibla), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('turning away and back buzzes once more', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      for (var i = 0; i < 50; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 60; i++) {
        h.compass.emit(_bearing + 60);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_pill(SpiritualStrings.facingQibla), findsNothing);
      for (var i = 0; i < 80; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(patterns, hasLength(2));
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('no haptic while searching', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, _bearing - 60, samples: 30);
      expect(patterns, isEmpty);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('haptics can be switched off globally', (tester) async {
      SeenHaptics.enabled = false;
      addTearDown(() => SeenHaptics.enabled = true);
      final h = _harness();
      await _pump(tester, h);
      for (var i = 0; i < 50; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(patterns, isEmpty);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('with reduced motion the pulse is a static halo',
        (tester) async {
      await loadHub(tester);
      final h = _harness();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: QiblaScreen(module: h.module),
      ));
      await tester.pumpAndSettle();
      for (var i = 0; i < 50; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_pill(SpiritualStrings.facingQibla), findsOneWidget);
      // Nothing loops: the tree settles.
      await tester.pumpAndSettle();
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('no compass sensor', () {
    testWidgets('shows the static bearing with a north reference and the sun',
        (tester) async {
      final h = _harness(compass: FakeCompassSensor(available: false));
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.noCompassTitle), findsOneWidget);
      expect(find.text(SpiritualStrings.noCompassBody), findsOneWidget);
      expect(find.textContaining('زاوية القبلة: $_bearingAr° من الشمال'), findsOneWidget);
      expect(find.textContaining('الشمس الآن باتجاه'), findsOneWidget);
      expect(find.text('ش'), findsOneWidget, reason: 'north marked on the dial');
      expect(find.byType(KaabaGlyph), findsWidgets);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('no live status pill, no accuracy card, but distance remains',
        (tester) async {
      final h = _harness(compass: FakeCompassSensor(available: false));
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.facingQibla), findsNothing);
      expect(find.text(SpiritualStrings.waitingCompass), findsNothing);
      expect(find.text(SpiritualStrings.compassAccuracy), findsNothing);
      expect(find.text(SpiritualStrings.distanceToMakkah), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the dial is static (north up) and never locks', (tester) async {
      final h = _harness(compass: FakeCompassSensor(available: false));
      await _pump(tester, h);
      expect(_dialHeading(tester), closeTo(0, 1e-6));
      expect(patterns, isEmpty);
      await disposeTree(tester);
    });

    testWidgets('a sensor that reports nothing falls back after the timeout',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.noCompassTitle), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.noCompassTitle), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('a device that reports a null heading falls back at once',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      h.compass.emit(null);
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.noCompassTitle), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the sun line is omitted at night', (tester) async {
      final h = PrayerHarness(
        fix: _riyadh,
        now: DateTime.utc(2026, 10, 3, 21), // 00:00 in Makkah
        compass: FakeCompassSensor(available: false),
      );
      await _pump(tester, h);
      expect(find.textContaining('الشمس الآن'), findsNothing);
      expect(find.text(SpiritualStrings.noCompassTitle), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('calibration', () {
    testWidgets('accuracy card shows excellent / good / poor / unknown',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100, accuracy: 10);
      expect(find.text(SpiritualStrings.accExcellent), findsOneWidget);
      await _heading(tester, h, 100, accuracy: 30);
      expect(find.text(SpiritualStrings.accGood), findsOneWidget);
      await _heading(tester, h, 100, accuracy: 45);
      expect(find.text(SpiritualStrings.accPoor), findsOneWidget);
      await _heading(tester, h, 100, accuracy: null);
      expect(find.text(SpiritualStrings.accUnknown), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('a warning banner appears only when accuracy is poor',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100, accuracy: 10);
      expect(find.text(SpiritualStrings.lowAccuracyBanner), findsNothing);
      await _heading(tester, h, 100, accuracy: 30);
      expect(find.text(SpiritualStrings.lowAccuracyBanner), findsNothing);
      await _heading(tester, h, 100, accuracy: 45);
      expect(find.text(SpiritualStrings.lowAccuracyBanner), findsOneWidget);
      await _heading(tester, h, 100, accuracy: 10);
      expect(find.text(SpiritualStrings.lowAccuracyBanner), findsNothing);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the banner\'s button opens the calibration help',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100, accuracy: 45);
      await tester.tap(find.descendant(
        of: find.ancestor(
          of: find.text(SpiritualStrings.lowAccuracyBanner),
          matching: find.byType(Container),
        ).first,
        matching: find.text(SpiritualStrings.calibrate),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(SpiritualStrings.calibrationTitle), findsOneWidget);
      expect(find.text(SpiritualStrings.calibrationStep1), findsOneWidget);
      expect(find.text(SpiritualStrings.calibrationStep2), findsOneWidget);
      expect(find.text(SpiritualStrings.calibrationStep3), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('the Kaaba card\'s "معايرة" opens it too, and "تم" closes it',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      await tester.ensureVisible(find.text(SpiritualStrings.calibrate));
      await tester.pump();
      await tester.tap(find.text(SpiritualStrings.calibrate));
      // The route's slide-in starts on the frame after the tap.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(SpiritualStrings.calibrationTitle), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.calibrationDone));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(SpiritualStrings.calibrationTitle), findsNothing);
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('location', () {
    testWidgets('denied: banner with a retry, Makkah, nothing to lock onto',
        (tester) async {
      final h = _harness(fix: const LocationDenied());
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.locFallbackDenied), findsOneWidget);
      expect(find.text(SpiritualStrings.nearKaaba), findsOneWidget);
      h.location.fix = _riyadh;
      await tester.tap(find.text(SpiritualStrings.allow));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.locFallbackDenied), findsNothing);
      expect(find.text('موقعك الحالي'), findsOneWidget);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('denied forever: opens the system settings', (tester) async {
      final h = _harness(fix: const LocationDeniedForever());
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.openSettings));
      await tester.pump();
      expect(h.location.settingsOpened, 1);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('choosing a city updates the angle and the distance',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.chooseCity));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جدة'));
      await tester.pumpAndSettle();
      expect(find.text('جدة'), findsOneWidget, reason: 'top bar subtitle');
      expect(find.text('١٠١°'), findsOneWidget);
      expect((await h.prefs.load()).cityId, 'jeddah');
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('a city with a denied GPS still gives a working compass',
        (tester) async {
      final h = _harness(fix: const LocationDenied());
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.chooseCity));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرياض'));
      await tester.pumpAndSettle();
      await _heading(tester, h, 100);
      expect(find.text('$_bearingAr°'), findsOneWidget);
      expect(find.text(SpiritualStrings.locFallbackDenied), findsNothing);
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('lifecycle', () {
    testWidgets('the sensor is released in the background and re-acquired',
        (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      expect(h.compass.listeners, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(h.compass.listeners, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.compass.listeners, 1);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('leaving the screen releases the sensor', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      await disposeTree(tester);
      expect(h.compass.listeners, 0);
      await h.compass.dispose();
    });
  });

  group('quality', () {
    testWidgets('survives text scale 2.0 (searching, locked, fallback)',
        (tester) async {
      final h = _harness();
      await _pump(tester, h, textScale: 2, size: const Size(390, 844));
      await _heading(tester, h, 100, accuracy: 45);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 50; i++) {
        h.compass.emit(_bearing);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
      await h.compass.dispose();

      final h2 = _harness(compass: FakeCompassSensor(available: false));
      await _pump(tester, h2, textScale: 2, size: const Size(390, 844));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('fits a small phone', (tester) async {
      final h = _harness();
      await _pump(tester, h, size: const Size(320, 640));
      await _heading(tester, h, 100);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('controls are at least 48 dp', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100, accuracy: 45);
      for (final label in [
        SpiritualStrings.back,
        SpiritualStrings.chooseCity,
      ]) {
        final size = tester.getSize(find.bySemanticsLabel(label).first);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
      for (final e in find.text(SpiritualStrings.calibrate).evaluate()) {
        final box = find
            .ancestor(of: find.byWidget(e.widget), matching: find.byType(Container))
            .evaluate()
            .map((c) => c.size!.height)
            .where((hgt) => hgt >= 48);
        expect(box, isNotEmpty);
      }
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });

  group('goldens', () {
    testWidgets('searching (turn right)', (tester) async {
      final h = PrayerHarness(
        fix: const LocationFound(-6.2088, 106.8456), // Jakarta: Qibla ≈ 295°
        now: _noonUtc,
      );
      await _pump(tester, h);
      await _heading(tester, h, 248, samples: 3);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_qibla_searching.png'),
      );
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('locked', (tester) async {
      final h = PrayerHarness(
        fix: const LocationFound(-6.2088, 106.8456),
        now: _noonUtc,
      );
      await _pump(tester, h);
      final b = QiblaMath.bearing(-6.2088, 106.8456);
      for (var i = 0; i < 60; i++) {
        h.compass.emit(b);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_qibla_locked.png'),
      );
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('no compass sensor', (tester) async {
      final h = PrayerHarness(
        fix: const LocationFound(-6.2088, 106.8456),
        now: _noonUtc,
        compass: FakeCompassSensor(available: false),
      );
      await _pump(tester, h);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_qibla_no_sensor.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('low accuracy banner', (tester) async {
      final h = PrayerHarness(
        fix: const LocationFound(-6.2088, 106.8456),
        now: _noonUtc,
      );
      await _pump(tester, h, size: const Size(390, 1000));
      await _heading(tester, h, 100, accuracy: 45);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_qibla_low_accuracy.png'),
      );
      await disposeTree(tester);
      await h.compass.dispose();
    });

    testWidgets('calibration sheet (figure-8 mid-loop)', (tester) async {
      final h = _harness();
      await _pump(tester, h);
      await _heading(tester, h, 100);
      await tester.ensureVisible(find.text(SpiritualStrings.calibrate));
      await tester.pump();
      await tester.tap(find.text(SpiritualStrings.calibrate));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_qibla_calibration.png'),
      );
      await disposeTree(tester);
      await h.compass.dispose();
    });
  });
}
