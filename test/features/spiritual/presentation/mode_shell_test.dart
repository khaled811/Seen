import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mock_dashboard_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_dashboard_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dashboard_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/dashboard/dashboard_view.dart';
import 'package:seen_booking/features/spiritual/presentation/duas/duas_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/agent_tab.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/mode_shell.dart';
import 'package:seen_booking/features/spiritual/presentation/spiritual_strings.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'mode_cubit_test.dart' show FakeModeRepository;

final _now = DateTime(2026, 10, 3, 11, 40);

Widget _app(FakeModeRepository repo) => MaterialApp(
      theme: AppTheme.light,
      home: ModeShell(
        agentHome: const Center(child: Text('AGENT-HOME')),
        repository: repo,
        createDashboardCubit: () => DashboardCubit(
          GetDashboardUseCase(MockDashboardRepository(clock: () => _now)),
          clock: () => _now,
        ),
      ),
    );

/// Disposes the tree so the dashboard's periodic timer is cancelled.
Future<void> _dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

const _dashboardMarker = SpiritualStrings.nextPrayer;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('launches in the persisted mode without flipping',
      (tester) async {
    await tester.pumpWidget(_app(FakeModeRepository(AppMode.manasik)));
    await tester.pumpAndSettle();
    expect(find.text(_dashboardMarker), findsOneWidget);
    expect(find.text('AGENT-HOME'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('flip button switches workspace and persists the choice',
      (tester) async {
    final repo = FakeModeRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('AGENT-HOME'), findsOneWidget);
    expect(find.text(_dashboardMarker), findsNothing);

    await tester.tap(find.text(SpiritualStrings.modeManasik));
    await tester.pumpAndSettle();
    expect(find.text(_dashboardMarker), findsOneWidget);
    expect(find.text('AGENT-HOME'), findsNothing);
    expect(repo.stored, AppMode.manasik);
    // Bar now offers the way back and shows the four Manasik tabs.
    expect(find.text(SpiritualStrings.modeAgent), findsOneWidget);
    expect(find.text(SpiritualStrings.navQuran), findsOneWidget);

    await tester.tap(find.text(SpiritualStrings.modeAgent));
    await tester.pumpAndSettle();
    expect(find.text('AGENT-HOME'), findsOneWidget);
    expect(repo.stored, AppMode.agent);
    await _dispose(tester);
  });

  testWidgets('dashboard state survives leaving and returning to the hub',
      (tester) async {
    await tester.pumpWidget(_app(FakeModeRepository(AppMode.manasik)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SpiritualStrings.modeAgent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SpiritualStrings.modeManasik));
    await tester.pumpAndSettle();
    expect(find.text('متبقي ٠٠:٣٥'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Manasik tabs swap the content', (tester) async {
    await tester.pumpWidget(_app(FakeModeRepository(AppMode.manasik)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SpiritualStrings.navAccount));
    await tester.pumpAndSettle();
    // Top bar title plus the nav label.
    expect(find.text(SpiritualStrings.navAccount), findsNWidgets(2));
    expect(find.text(_dashboardMarker), findsNothing);

    await tester.tap(find.text(SpiritualStrings.navHome));
    await tester.pumpAndSettle();
    expect(find.text(_dashboardMarker), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('tapping a service opens its live screen (no placeholder)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(FakeModeRepository(AppMode.manasik)));
    await tester.pumpAndSettle();
    final tile = find.text(SpiritualStrings.svcDuas);
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find
          .descendant(
            of: find.byType(DashboardView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(DuasScreen), findsOneWidget);
    expect(find.text(SpiritualStrings.hubComingSoon), findsNothing);
    await _dispose(tester);
  });

  testWidgets('agent mode shows Home plus the supplied tabs; a tab opens its screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const Center(child: Text('AGENT-HOME')),
          repository: FakeModeRepository(),
          agentTabs: [
            AgentTab(icon: Icons.list, label: 'طلباتي', onTap: (_) => opened = 'requests'),
            AgentTab(icon: Icons.wallet, label: 'المحفظة', onTap: (_) => opened = 'wallet'),
            AgentTab(icon: Icons.people, label: 'الوكلاء', onTap: (_) => opened = 'agents'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final l in ['Home', 'طلباتي', 'المحفظة', 'الوكلاء']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    await tester.tap(find.text('المحفظة'));
    expect(opened, 'wallet');
    await _dispose(tester);
  });

  testWidgets('المناسك tab lists the rites; حسابي opens the account sheet hook',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var account = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const SizedBox(),
          repository: FakeModeRepository(AppMode.manasik),
          onAccount: (_) => account++,
          createDashboardCubit: () => DashboardCubit(
            GetDashboardUseCase(MockDashboardRepository(clock: () => _now)),
            clock: () => _now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(SpiritualStrings.navManasik));
    await tester.pumpAndSettle();
    expect(find.text(SpiritualStrings.hubComingSoon), findsNothing);
    for (final l in [
      SpiritualStrings.svcTawaf,
      SpiritualStrings.svcPrayer,
      SpiritualStrings.svcQibla,
      SpiritualStrings.svcDuas,
      SpiritualStrings.svcTasbeeh,
    ]) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    await tester.tap(find.text(SpiritualStrings.navAccount));
    await tester.pumpAndSettle();
    expect(account, 1);
    expect(find.text(SpiritualStrings.hubComingSoon), findsNothing);
    await _dispose(tester);
  });

  testWidgets('agent tabs switch pages inside the shell; the bar stays; back goes home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var account = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ModeShell(
          agentHome: const Center(child: Text('AGENT-HOME')),
          repository: FakeModeRepository(),
          agentTabs: [
            AgentTab(
              icon: Icons.list,
              label: 'طلباتي',
              builder: (_) => const Center(child: Text('PAGE-REQUESTS')),
            ),
            AgentTab(
              icon: Icons.wallet,
              label: 'المحفظة',
              builder: (_) => const Center(child: Text('PAGE-WALLET')),
            ),
            AgentTab(icon: Icons.person, label: 'حسابي', onTap: (_) => account++),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AGENT-HOME'), findsOneWidget);

    await tester.tap(find.text('طلباتي'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-REQUESTS'), findsOneWidget);
    expect(find.text('AGENT-HOME').hitTestable(), findsNothing);
    expect(find.text('المحفظة'), findsOneWidget, reason: 'the bar stays');

    await tester.tap(find.text('المحفظة'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-WALLET'), findsOneWidget);
    expect(find.text('PAGE-REQUESTS').hitTestable(), findsNothing);

    // An action tab does not change the page.
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    expect(account, 1);
    expect(find.text('PAGE-WALLET'), findsOneWidget);

    // System back returns to Home, then the next back would leave.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('AGENT-HOME'), findsOneWidget);
    expect(find.text('PAGE-WALLET').hitTestable(), findsNothing);

    // Re-opening a visited tab keeps it built (no rebuild from scratch).
    await tester.tap(find.text('طلباتي'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-REQUESTS'), findsOneWidget);
    await _dispose(tester);
  });
}
