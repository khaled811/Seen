import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/di/quran_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/last_read.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_ayah_search_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_index_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/quran/quran_reader_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/mode_shell.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';

import '../support/fakes.dart';
import '../support/quran_harness.dart';
import 'mode_cubit_test.dart' show FakeModeRepository;

final _now = DateTime(2026, 10, 3, 11, 40);

void main() {
  setUpAll(QuranHarness.preload);

  group('dashboard reading card (real last read)', () {
    Future<String> surahLine(QuranHarness h) async {
      final repo = MockDashboardRepository(
        clock: () => _now,
        readerState: h.reader,
        quran: QuranHarness.sharedQuran,
      );
      final r = (await repo.load()).getOrElse((_) => throw 'x').reading;
      return '${r.surahName}:${r.page}';
    }

    test('with nothing read yet it starts at Al-Fatihah, page 1', () async {
      expect(await surahLine(QuranHarness()), 'الفاتحة:1');
    });

    test('with a saved position it shows that surah and page', () async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      expect(await surahLine(h), 'الكهف:293');
      final h2 = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 2, ayah: 255)),
      );
      expect(await surahLine(h2), 'البقرة:42');
    });

    test('without the reader sources it keeps the fixture', () async {
      final r = (await MockDashboardRepository(clock: () => _now).load())
          .getOrElse((_) => throw 'x')
          .reading;
      expect('${r.surahName}:${r.page}', 'الكهف:293');
    });
  });

  group('inside the Manasik shell', () {
    late QuranModule previous;

    setUp(() => previous = QuranModule.instance);
    tearDown(() => QuranModule.instance = previous);

    Widget app(QuranHarness h) {
      QuranModule.instance = h.module;
      return MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const Center(child: Text('AGENT-HOME')),
          repository: FakeModeRepository(AppMode.manasik),
          createDashboardCubit: () => DashboardCubit(
            GetDashboardUseCase(
              MockDashboardRepository(
                clock: () => _now,
                sessions: InMemoryTawafRepo(),
                readerState: h.reader,
                quran: QuranHarness.sharedQuran,
              ),
            ),
            clock: () => _now,
          ),
        ),
      );
    }

    Future<void> pumpShell(WidgetTester tester, QuranHarness h) async {
      await loadHub(tester);
      await tester.pumpWidget(app(h));
      await tester.pumpAndSettle();
    }

    testWidgets('the المصحف tab shows the index, embedded', (tester) async {
      final h = QuranHarness();
      await pumpShell(tester, h);
      await tester.tap(find.text(SpiritualStrings.navQuran));
      await tester.pumpAndSettle();
      expect(find.byType(QuranIndexScreen), findsOneWidget);
      expect(find.text(SpiritualStrings.searchHint), findsOneWidget);
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('tab -> surah -> reader -> back stays on the tab',
        (tester) async {
      final h = QuranHarness();
      await pumpShell(tester, h);
      await tester.tap(find.text(SpiritualStrings.navQuran));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفاتحة'));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsNothing);
      expect(find.text(SpiritualStrings.searchHint), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('dashboard "إكمال القراءة" opens the reader at the saved ayah',
        (tester) async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      await pumpShell(tester, h);
      expect(find.text('سورة الكهف • صفحة ٢٩٣'), findsOneWidget);
      await tester.tap(find.text(SpiritualStrings.continueReading));
      await tester.pumpAndSettle();
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(find.text('سورة الكهف'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('with nothing read, "إكمال القراءة" opens Al-Fatihah',
        (tester) async {
      final h = QuranHarness();
      await pumpShell(tester, h);
      await tester.tap(find.text(SpiritualStrings.continueReading));
      await tester.pumpAndSettle();
      expect(find.text('سورة الفاتحة'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the dashboard card refreshes after reading elsewhere',
        (tester) async {
      final h = QuranHarness(
        initial: const ReaderState(lastRead: LastRead(surah: 18, ayah: 3)),
      );
      await pumpShell(tester, h);
      await tester.tap(find.text(SpiritualStrings.continueReading));
      await tester.pumpAndSettle();
      // The user read on and the position was saved while the reader was open.
      h.reader.state = const ReaderState(lastRead: LastRead(surah: 2, ayah: 255));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('سورة البقرة • صفحة ٤٢'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('the "المصحف الشريف" service opens the index with a back button',
        (tester) async {
      final h = QuranHarness();
      await pumpShell(tester, h);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.svcQuran),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      // "Built" is not "on screen": bring the tile fully into view first.
      await tester.ensureVisible(find.text(SpiritualStrings.svcQuran));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SpiritualStrings.svcQuran));
      await tester.pumpAndSettle();
      expect(find.byType(QuranIndexScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(QuranIndexScreen), findsNothing);
      await disposeTree(tester);
    });
  });

  group('ayah text search screen', () {
    Future<void> pumpSearch(
      WidgetTester tester,
      QuranHarness h,
      String query,
      List<(int, int)> opened,
    ) =>
        pumpHub(
          tester,
          QuranAyahSearchScreen(
            query: query,
            module: h.module,
            onOpen: (s, a) => opened.add((s, a)),
          ),
        );

    testWidgets('lists matching ayahs with their reference and page',
        (tester) async {
      final h = QuranHarness();
      await pumpSearch(tester, h, 'الحمد لله رب العالمين', []);
      expect(find.text(SpiritualStrings.searchResults), findsOneWidget);
      expect(find.text('«الحمد لله رب العالمين»'), findsOneWidget);
      expect(find.text('سورة الفاتحة · الآية ٢'), findsOneWidget);
      expect(find.text('صفحة ١'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('tapping a result opens it in the reader', (tester) async {
      final h = QuranHarness();
      final opened = <(int, int)>[];
      await pumpSearch(tester, h, 'الحمد لله رب العالمين', opened);
      await tester.tap(find.text('سورة الفاتحة · الآية ٢'));
      await tester.pumpAndSettle();
      expect(opened, [(1, 2)]);
      await disposeTree(tester);
    });

    testWidgets('no match shows a message', (tester) async {
      final h = QuranHarness();
      await pumpSearch(tester, h, 'zzzzqqq', []);
      expect(find.text(SpiritualStrings.noAyahMatches), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a very common word is capped with a notice', (tester) async {
      final h = QuranHarness();
      await pumpSearch(tester, h, 'الله', []);
      await tester.scrollUntilVisible(
        find.text(SpiritualStrings.resultsCapped),
        600,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      expect(find.text(SpiritualStrings.resultsCapped), findsOneWidget);
      await disposeTree(tester);
    });
  });
}
