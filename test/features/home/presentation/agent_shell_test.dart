import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/config/feature_flags.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';
import 'package:seen_booking/features/home/presentation/screens/agent_shell.dart';

const _session = UserSession(
  userId: 'AG-1',
  userType: UserType.agent,
  positionRaw: '',
  branchId: 'b',
  permissionCodes: {},
);

Widget _app() => MaterialApp(
      theme: AppTheme.light,
      home: AgentShell(
        session: _session,
        pageBuilders: [
          for (final n in ['HOME', 'REQUESTS', 'WALLET', 'AGENTS', 'ACCOUNT'])
            (_) => Center(child: Text(n)),
        ],
      ),
    );

void main() {
  test('the spiritual hub is dormant by default', () {
    expect(kEnableSpiritualHub, isFalse);
  });

  testWidgets('five tabs, no flip switcher', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byIcon(Icons.flip), findsNothing);
  });

  testWidgets('tabs switch pages, keep the bar, and stay alive', (tester) async {
    await tester.pumpWidget(_app());
    final bar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: bar, matching: find.byType(NavigationDestination)).at(1));
    await tester.pumpAndSettle();
    expect(find.text('REQUESTS').hitTestable(), findsOneWidget);
    expect(find.text('HOME').hitTestable(), findsNothing);
    expect(bar, findsOneWidget);

    await tester.tap(find.descendant(of: bar, matching: find.byType(NavigationDestination)).at(2));
    await tester.pumpAndSettle();
    expect(find.text('WALLET').hitTestable(), findsOneWidget);
    await tester.tap(find.descendant(of: bar, matching: find.byType(NavigationDestination)).at(3));
    await tester.pumpAndSettle();
    expect(find.text('AGENTS').hitTestable(), findsOneWidget);
  });

  testWidgets('the account tab switches in place and keeps the bar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(NavigationDestination),
    ).at(4));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT').hitTestable(), findsOneWidget);
    expect(find.text('HOME').hitTestable(), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('system back from another tab returns home', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(NavigationDestination),
    ).at(2));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME').hitTestable(), findsOneWidget);
  });
}
