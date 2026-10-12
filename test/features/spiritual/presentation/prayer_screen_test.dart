import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_tokens.dart';
import 'package:seen_booking/features/spiritual/domain/entities/location_fix.dart';
import 'package:seen_booking/features/spiritual/domain/entities/prayer_id.dart';
import 'package:seen_booking/features/spiritual/domain/services/notification_scheduler.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/prayer_event.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/horizon_card.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/prayer_rows_card.dart';
import 'package:seen_booking/features/spiritual/presentation/prayer/prayer_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/press_scale.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_segmented.dart';

import '../support/prayer_fakes.dart';
import '../support/quran_harness.dart' show disposeTree, pumpHub;

Future<void> _pump(
  WidgetTester tester,
  PrayerHarness h, {
  double textScale = 1,
  Size size = const Size(390, 1000),
}) =>
    pumpHub(
      tester,
      PrayerScreen(module: h.module),
      textScale: textScale,
      size: size,
    );

/// A segmented-control tab (the word "اليوم" also heads a table column).
Finder _tab(String label) => find.descendant(
      of: find.byType(SpiritualSegmented<PrayerView>),
      matching: find.text(label),
    );

Finder _alertButton(String prayer, String mode) =>
    find.bySemanticsLabel('تنبيه $prayer: $mode، اضغط للتغيير');

/// Taps something inside the (long, scrollable) settings sheet.
Future<void> _tapSheet(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(SpiritualStrings.prayerSettings));
  await tester.pumpAndSettle();
}

void main() {
  group('day view', () {
    testWidgets('header, tabs and date navigator', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.prayerTitle), findsOneWidget);
      expect(find.text('موقعك الحالي · تقويم أم القرى'), findsOneWidget);
      expect(find.text(SpiritualStrings.viewDay), findsOneWidget);
      expect(find.text(SpiritualStrings.viewMonth), findsOneWidget);
      expect(find.text('السبت ٢٢ ربيع الآخر'), findsOneWidget);
      expect(find.text('٣ أكتوبر ٢٠٢٦'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('seven rows with their times, in Arabic digits', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.byType(PrayerRow), findsNWidgets(7));
      for (final id in PrayerId.values) {
        expect(find.text(id.nameAr), findsWidgets, reason: id.nameAr);
      }
      expect(find.text('٤:٥٨ ص'), findsOneWidget); // fajr
      expect(find.text('٦:١٢ ص'), findsOneWidget); // sunrise
      expect(find.text('١٢:١٥ م'), findsWidgets); // dhuhr (row + caption)
      expect(find.text('٣:٣٧ م'), findsOneWidget);
      expect(find.text('٦:٠٤ م'), findsOneWidget);
      expect(find.text('٧:٣٤ م'), findsOneWidget);
      expect(find.text('١١:٣١ م'), findsOneWidget); // midnight
      await disposeTree(tester);
    });

    testWidgets('the next prayer is highlighted with its countdown',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.text('بعد ٣٥ د'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('row sub-lines: adhan mode, reminders, last third of the night',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.modeSound), findsNWidgets(5));
      expect(find.text('تذكير · صامت'), findsOneWidget);
      expect(find.text('الثلث الأخير للقيام ١:٢٠ ص · صامت'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the hint under the list', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.alertHint), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('horizon', () {
    testWidgets('the caption describes the next prayer first', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.text('الظهر · ١٢:١٥ م'), findsOneWidget);
      expect(find.text('بعد ٣٥ دقيقة'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('tapping a marker selects it', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel('العصر ٣:٣٧ م'));
      await tester.pumpAndSettle();
      expect(find.text('العصر · ٣:٣٧ م'), findsOneWidget);
      expect(find.text('بعد ٣ س ٥٧ د'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a past marker says it has passed', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel('الفجر ٤:٥٨ ص'));
      await tester.pumpAndSettle();
      expect(find.text('الفجر · ٤:٥٨ ص'), findsOneWidget);
      expect(find.text(SpiritualStrings.pastFeminine), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('الشروق ٦:١٢ ص'));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.pastMasculine), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('all seven markers are tappable and at least 40 dp',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      final card = tester.getRect(find.byType(HorizonCard));
      for (final label in [
        'الفجر ٤:٥٨ ص',
        'الشروق ٦:١٢ ص',
        'الظهر ١٢:١٥ م',
        'العصر ٣:٣٧ م',
        'المغرب ٦:٠٤ م',
        'العشاء ٧:٣٤ م',
        'منتصف الليل ١١:٣١ م',
      ]) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.width, greaterThanOrEqualTo(40), reason: label);
        expect(card.contains(rect.center), isTrue, reason: label);
      }
      await disposeTree(tester);
    });
  });

  group('alert buttons', () {
    testWidgets('cycle sound -> vibrate -> silent and persist', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(_alertButton('العصر', 'أذان كامل'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.vibration), findsOneWidget);
      expect(h.prefs.value.modeOf(PrayerId.asr), AlertMode.vibrate);
      expect(find.text(SpiritualStrings.modeVibrate), findsOneWidget);

      await tester.tap(_alertButton('العصر', 'اهتزاز فقط'));
      await tester.pumpAndSettle();
      expect(h.prefs.value.modeOf(PrayerId.asr), AlertMode.silent);
      expect(find.text(SpiritualStrings.modeSound), findsNWidgets(4));

      await tester.tap(_alertButton('العصر', 'صامت'));
      await tester.pumpAndSettle();
      expect(h.prefs.value.modeOf(PrayerId.asr), AlertMode.sound);
      await disposeTree(tester);
    });

    testWidgets('every change re-plans the reminders', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      final calls = h.scheduler.replaceCalls;
      await tester.tap(_alertButton('الفجر', 'أذان كامل'));
      await tester.pumpAndSettle();
      expect(h.scheduler.replaceCalls, calls + 1);
      await disposeTree(tester);
    });

    testWidgets('a failed save warns', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      h.prefs.failSave = true;
      await tester.tap(_alertButton('الفجر', 'أذان كامل'));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.saveFailed), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('are 48 dp square', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      final size = tester.getSize(_alertButton('العصر', 'أذان كامل'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await disposeTree(tester);
    });
  });

  group('date navigation', () {
    testWidgets('next day updates the titles and drops the countdown',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.next));
      await tester.pumpAndSettle();
      expect(find.text('الأحد ٢٣ ربيع الآخر'), findsOneWidget);
      expect(find.text('٤ أكتوبر ٢٠٢٦'), findsOneWidget);
      expect(find.text('بعد ٣٥ د'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('previous day, and the times shift', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.previous));
      await tester.pumpAndSettle();
      expect(find.text('الجمعة ٢١ ربيع الآخر'), findsOneWidget);
      expect(find.text('٢ أكتوبر ٢٠٢٦'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a past day shows everything as past', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.previous));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^العصر')));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.pastFeminine), findsNothing,
          reason: 'relative text is only shown for today');
      await disposeTree(tester);
    });

    testWidgets('navigation buttons are at least 48 dp', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      for (final label in [
        SpiritualStrings.next,
        SpiritualStrings.previous,
        SpiritualStrings.prayerSettings,
        SpiritualStrings.back,
      ]) {
        final size = tester.getSize(find.bySemanticsLabel(label).first);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
      await disposeTree(tester);
    });
  });

  group('month view', () {
    Future<void> toMonth(WidgetTester tester) async {
      await tester.tap(find.text(SpiritualStrings.viewMonth));
      await tester.pumpAndSettle();
    }

    testWidgets('titles and column headings', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      expect(find.text('ربيع الآخر ١٤٤٨'), findsOneWidget);
      expect(find.text('سبتمبر – أكتوبر ٢٠٢٦'), findsOneWidget);
      expect(find.text(SpiritualStrings.colDay), findsNWidgets(2),
          reason: 'the tab and the table heading share the word');
      for (final c in [
        'الفجر',
        'الشروق',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
      ]) {
        expect(find.text(c), findsOneWidget, reason: c);
      }
      expect(find.byType(PrayerRow), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('the header stays in view while the table scrolls',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      expect(_tab(SpiritualStrings.viewDay), findsOneWidget);
      expect(find.text('ربيع الآخر ١٤٤٨'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.getRect(_tab(SpiritualStrings.viewDay)).top, lessThan(200));
      await disposeTree(tester);
    });

    testWidgets('scrolls to today and shows its times', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      expect(find.text('٣ أكتوبر'), findsOneWidget, reason: 'today\'s row is on screen');
      expect(find.text('٢٢'), findsOneWidget);
      expect(find.text('٤:٥٨'), findsWidgets);
      expect(find.text('١٢:١٥'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('today\'s row is tinted with the accent number', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      final text = tester.widget<Text>(find.text('٢٢'));
      expect(text.style?.color, SpiritualTokens.light.accent);
      await disposeTree(tester);
    });

    testWidgets('rows are built lazily', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      final built = find.textContaining(RegExp('(أكتوبر|سبتمبر)')).evaluate().length;
      expect(built, lessThan(25), reason: 'not all 30 rows are in the tree');
      await disposeTree(tester);
    });

    testWidgets('next month', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.next));
      await tester.pumpAndSettle();
      expect(find.text('جمادى الأولى ١٤٤٨'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('back to the day view', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await toMonth(tester);
      await tester.tap(_tab(SpiritualStrings.viewDay));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerRow), findsNWidgets(7));
      await disposeTree(tester);
    });
  });

  group('settings sheet', () {
    testWidgets('lists the options', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      expect(find.text(SpiritualStrings.prayerSettings), findsWidgets);
      expect(find.text(SpiritualStrings.settingsMethod), findsOneWidget);
      expect(find.text('تقويم أم القرى'), findsWidgets);
      expect(find.text(SpiritualStrings.settingsMadhab), findsOneWidget);
      expect(find.text(SpiritualStrings.settingsPreAlert), findsOneWidget);
      expect(find.text(SpiritualStrings.settingsLocation), findsOneWidget);
      expect(find.text(SpiritualStrings.automaticLocation), findsOneWidget);
      expect(find.text(SpiritualStrings.notifGranted), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('changing the calculation method persists and recalculates',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      await _tapSheet(tester, find.text('رابطة العالم الإسلامي'));
      expect(h.prefs.value.method.name, 'muslimWorldLeague');
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.close));
      await tester.pumpAndSettle();
      expect(find.text('٥:٠١ ص'), findsOneWidget, reason: 'fajr +3 min');
      expect(find.text('موقعك الحالي · رابطة العالم الإسلامي'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('Asr school', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      await _tapSheet(tester, find.text('الحنفي'));
      expect(h.prefs.value.madhab.name, 'hanafi');
      await disposeTree(tester);
    });

    testWidgets('pre-alert chips', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      await _tapSheet(tester, find.text('١٥ د'));
      expect(h.prefs.value.preAlertMinutes, 15);
      expect(h.scheduler.scheduled.any((r) => r.isPreAlert), isTrue);
      await disposeTree(tester);
    });

    testWidgets('choosing a city', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      await _tapSheet(tester, find.text('الرياض'));
      expect(h.prefs.value.cityId, 'riyadh');
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.close));
      await tester.pumpAndSettle();
      expect(find.text('الرياض · تقويم أم القرى'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('notifications not asked yet: an enable button', (tester) async {
      final h = PrayerHarness(permission: NotificationPermission.notDetermined);
      h.prefs.value = h.prefs.value.copyWith(notificationsPrompted: true);
      await _pump(tester, h);
      await _openSettings(tester);
      expect(find.text(SpiritualStrings.notifUnknown), findsOneWidget);
      await _tapSheet(tester, find.text(SpiritualStrings.enableNotifications));
      expect(h.scheduler.requests, 1);
      expect(find.text(SpiritualStrings.notifGranted), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('notifications refused: explains how to fix it', (tester) async {
      final h = PrayerHarness(permission: NotificationPermission.denied);
      await _pump(tester, h);
      await _openSettings(tester);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.notifDenied),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(SpiritualStrings.enableNotifications), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('is honest that the full adhan recording is not bundled yet',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await _openSettings(tester);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.adhanAudioNote),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(SpiritualStrings.adhanAudioNote), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('location problems degrade gracefully', () {
    testWidgets('permission denied: banner, Makkah, and a way to retry',
        (tester) async {
      final h = PrayerHarness(fix: const LocationDenied());
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.locFallbackDenied), findsOneWidget);
      expect(find.text('مكة المكرمة · تقويم أم القرى'), findsOneWidget);
      h.location.fix = const LocationFound(24.7136, 46.6753);
      await tester.tap(find.text(SpiritualStrings.allow));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.locFallbackDenied), findsNothing);
      expect(find.text('موقعك الحالي · تقويم أم القرى'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('permanently denied: opens the system settings',
        (tester) async {
      final h = PrayerHarness(fix: const LocationDeniedForever());
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.locFallbackForever), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.openSettings));
      await tester.pumpAndSettle();
      expect(h.location.settingsOpened, 1);
      await disposeTree(tester);
    });

    testWidgets('location services off', (tester) async {
      final h = PrayerHarness(fix: const LocationServiceDisabled());
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.locFallbackServiceOff), findsOneWidget);
      expect(find.text(SpiritualStrings.openSettings), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('no position available', (tester) async {
      final h = PrayerHarness(fix: const LocationUnavailable());
      await _pump(tester, h);
      expect(find.text(SpiritualStrings.locFallbackUnavailable), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the times are still shown while degraded', (tester) async {
      final h = PrayerHarness(fix: const LocationDenied());
      await _pump(tester, h);
      expect(find.byType(PrayerRow), findsNWidgets(7));
      expect(find.text('بعد ٣٥ د'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('picking a city removes the banner', (tester) async {
      final h = PrayerHarness(fix: const LocationDenied());
      await _pump(tester, h);
      await _openSettings(tester);
      await _tapSheet(tester, find.text('جدة'));
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(SpiritualStrings.locFallbackDenied), findsNothing);
      await disposeTree(tester);
    });
  });

  group('quality', () {
    testWidgets('day view survives text scale 2.0', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h, textScale: 2, size: const Size(390, 844));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('month view survives text scale 2.0', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h, textScale: 2, size: const Size(390, 844));
      await tester.tap(find.text(SpiritualStrings.viewMonth));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('settings sheet survives text scale 2.0', (tester) async {
      final h = PrayerHarness(fix: const LocationDenied());
      await _pump(tester, h, textScale: 2, size: const Size(390, 844));
      await _openSettings(tester);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('fits a small phone (320 dp wide)', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.byType(HorizonCard), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('PressScale-based controls expose button semantics',
        (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      expect(find.byType(PressScale), findsWidgets);
      await disposeTree(tester);
    });
  });

  group('goldens', () {
    testWidgets('day view @ 390x1000 (matches Prayer.dc.html)', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_prayer_day.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('month view', (tester) async {
      final h = PrayerHarness();
      await _pump(tester, h);
      await tester.tap(find.text(SpiritualStrings.viewMonth));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_prayer_month.png'),
      );
      await disposeTree(tester);
    });

    testWidgets('settings sheet (degraded location)', (tester) async {
      final h = PrayerHarness(fix: const LocationDenied());
      await _pump(tester, h, size: const Size(390, 844));
      await _openSettings(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_prayer_settings.png'),
      );
      await disposeTree(tester);
    });
  });
}
