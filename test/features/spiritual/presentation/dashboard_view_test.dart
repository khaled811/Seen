import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/dashboard/dashboard_view.dart';
import 'package:seen_booking/features/spiritual/presentation/navigation/spiritual_destination.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_theme.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_scaffold.dart';

final _now = DateTime(2026, 10, 3, 11, 40);

Future<List<SpiritualDestination>> _pump(
  WidgetTester tester, {
  bool withRite = true,
  double textScale = 1,
  Size size = const Size(390, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final taps = <SpiritualDestination>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: BlocProvider(
        create: (_) => DashboardCubit(
          GetDashboardUseCase(
            MockDashboardRepository(clock: () => _now, withActiveRite: withRite),
          ),
          clock: () => _now,
          tickInterval: const Duration(hours: 1),
        )..load(),
        child: SpiritualTheme(
          child: SpiritualScaffold(
            gutter: false,
            body: DashboardView(onNavigate: taps.add),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

Future<void> _dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  testWidgets('shows the header, next prayer and timeline from the mockup',
      (tester) async {
    await _pump(tester);
    expect(find.text('مكة المكرمة'), findsOneWidget);
    expect(find.text('١٤ ربيع الآخر ١٤٤٨'), findsOneWidget);
    expect(find.text(SpiritualStrings.nextPrayer), findsOneWidget);
    expect(find.text('متبقي ٠٠:٣٥'), findsOneWidget);
    // 12:15 headline + timeline entry, plus the other four times.
    expect(find.text('١٢:١٥'), findsNWidgets(2));
    expect(find.text('ظهرًا'), findsOneWidget);
    for (final t in ['٤:٥٨', '٣:٣٧', '٦:٠٤', '٧:٣٤']) {
      expect(find.text(t), findsOneWidget);
    }
    for (final n in ['الفجر', 'العصر', 'المغرب', 'العشاء']) {
      expect(find.text(n), findsOneWidget);
    }
    await _dispose(tester);
  });

  testWidgets('active rite card shows lap progress and steps', (tester) async {
    await _pump(tester);
    expect(find.text(SpiritualStrings.todaysRites), findsOneWidget);
    expect(find.text(SpiritualStrings.hajjMode), findsOneWidget);
    expect(find.text(SpiritualStrings.tawafOfUmrah), findsOneWidget);
    expect(find.text('الشوط ٣ من ٧'), findsOneWidget);
    expect(find.text(SpiritualStrings.stepIhram), findsOneWidget);
    expect(find.text(SpiritualStrings.continueRite), findsOneWidget);
    expect(find.text(SpiritualStrings.startUmrah), findsNothing);
    await _dispose(tester);
  });

  testWidgets('without an active rite a quieter start card is shown',
      (tester) async {
    await _pump(tester, withRite: false);
    expect(find.text(SpiritualStrings.startUmrah), findsOneWidget);
    expect(find.text(SpiritualStrings.continueRite), findsNothing);
    expect(find.text(SpiritualStrings.hajjMode), findsNothing);
    await _dispose(tester);
  });

  testWidgets('reading card shows the daily wird', (tester) async {
    await _pump(tester);
    expect(find.text('سورة الكهف • صفحة ٢٩٣'), findsOneWidget);
    expect(find.text('٦٠٪'), findsOneWidget);
    expect(find.text('٣ من ٥ صفحات'), findsOneWidget);
    expect(find.text(SpiritualStrings.continueReading), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('renders all six service tiles', (tester) async {
    await _pump(tester);
    for (final label in [
      SpiritualStrings.svcQuran,
      SpiritualStrings.svcTawaf,
      SpiritualStrings.svcDuas,
      SpiritualStrings.svcQibla,
      SpiritualStrings.svcPrayer,
      SpiritualStrings.svcTasbeeh,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await _dispose(tester);
  });

  group('navigation', () {
    final cases = <String, SpiritualDestination>{
      SpiritualStrings.continueRite: SpiritualDestination.tawaf,
      SpiritualStrings.continueReading: SpiritualDestination.quranReader,
      SpiritualStrings.svcQuran: SpiritualDestination.quranIndex,
      SpiritualStrings.svcTawaf: SpiritualDestination.tawaf,
      SpiritualStrings.svcDuas: SpiritualDestination.duas,
      SpiritualStrings.svcQibla: SpiritualDestination.qibla,
      SpiritualStrings.svcPrayer: SpiritualDestination.prayer,
      SpiritualStrings.svcTasbeeh: SpiritualDestination.tasbeeh,
      'مكة المكرمة': SpiritualDestination.cityPicker,
      SpiritualStrings.nextPrayer: SpiritualDestination.prayer,
    };
    cases.forEach((label, destination) {
      testWidgets('"$label" -> ${destination.name}', (tester) async {
        final taps = await _pump(tester);
        await tester.tap(find.text(label));
        await tester.pump();
        expect(taps, [destination]);
        await _dispose(tester);
      });
    });

    testWidgets('profile button opens the profile', (tester) async {
      final taps = await _pump(tester);
      await tester.tap(find.bySemanticsLabel(SpiritualStrings.profileSettings));
      await tester.pump();
      expect(taps, [SpiritualDestination.profile]);
      await _dispose(tester);
    });
  });

  testWidgets('tappable targets are at least 48 dp tall', (tester) async {
    await _pump(tester);
    for (final label in [
      SpiritualStrings.continueRite,
      SpiritualStrings.continueReading,
      SpiritualStrings.svcQuran,
    ]) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox || w is Container,
        ),
      );
      final heights = target.evaluate().map((e) => e.size!.height);
      expect(heights.any((h) => h >= 48), isTrue, reason: label);
    }
    await _dispose(tester);
  });

  testWidgets('survives text scale 2.0 without overflow', (tester) async {
    await _pump(tester, textScale: 2, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('golden: dashboard @ 390 px', (tester) async {
    await loadAppFonts();
    await _pump(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/spiritual_dashboard.png'),
    );
    await _dispose(tester);
  });
}
