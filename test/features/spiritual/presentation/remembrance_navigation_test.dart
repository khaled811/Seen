import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/di/dua_module.dart';
import 'package:seen_booking/features/spiritual/di/tasbeeh_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/dashboard/dashboard_view.dart';
import 'package:seen_booking/features/spiritual/presentation/duas/duas_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/mode_shell.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';
import 'package:seen_booking/features/spiritual/presentation/tasbeeh/tasbeeh_screen.dart';

import 'mode_cubit_test.dart' show FakeModeRepository;
import '../support/remembrance_fakes.dart';

final _now = DateTime(2026, 10, 3, 11, 40);

Future<void> _openFromDashboard(WidgetTester tester, String tile) async {
  final finder = find.text(tile);
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(DashboardView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DuaModule previousDuas;
  late TasbeehModule previousTasbeeh;

  setUp(() {
    previousDuas = DuaModule.instance;
    previousTasbeeh = TasbeehModule.instance;
    DuaModule.instance = DuaHarness().module;
    TasbeehModule.instance = TasbeehHarness().module;
  });

  tearDown(() {
    DuaModule.instance = previousDuas;
    TasbeehModule.instance = previousTasbeeh;
  });

  testWidgets('the dashboard tiles open the real duas and tasbeeh screens',
      (tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const SizedBox(),
          repository: FakeModeRepository(AppMode.manasik),
          createDashboardCubit: () => DashboardCubit(
            GetDashboardUseCase(MockDashboardRepository(clock: () => _now)),
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openFromDashboard(tester, SpiritualStrings.svcDuas);
    expect(find.byType(DuasScreen), findsOneWidget);
    expect(find.text(SpiritualStrings.duasTitle), findsOneWidget);
    expect(find.text(SpiritualStrings.hubComingSoon), findsNothing);

    // The tasbeeh shortcut in the duas top bar, then back twice.
    await tester.tap(find.byIcon(Icons.blur_circular));
    await tester.pumpAndSettle();
    expect(find.byType(TasbeehScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TasbeehScreen), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(DuasScreen), findsNothing);

    await _openFromDashboard(tester, SpiritualStrings.svcTasbeeh);
    expect(find.byType(TasbeehScreen), findsOneWidget);
    expect(find.text(SpiritualStrings.tasbeehTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
