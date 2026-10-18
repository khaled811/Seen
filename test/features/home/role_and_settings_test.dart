// ROLE-01 (role-based views) and ACC-04 (settings). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/preferences/balance_privacy_cubit.dart';
import 'package:seen_booking/core/presentation/widgets/balance_card.dart';
import 'package:seen_booking/core/presentation/widgets/chrome.dart';
import 'package:seen_booking/core/presentation/widgets/components.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';
import 'package:seen_booking/features/home/presentation/screens/agent_shell.dart';
import 'package:seen_booking/features/home/presentation/screens/home_screen.dart';
import 'package:seen_booking/features/home/presentation/screens/role_home_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/settings_screen.dart';

UserSession _session(String position) => UserSession(
      userId: 'AG-1',
      userType: UserType.agent,
      positionRaw: position,
      branchId: 'b',
      permissionCodes: const {},
    );

Widget _app(Widget home, {List<BlocProvider> providers = const []}) {
  final app = MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light,
    home: home,
  );
  return providers.isEmpty ? app : MultiBlocProvider(providers: providers, child: app);
}

/// The secure-storage plugin channel, backed by a map.
final _store = <String, String>{};

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
        switch (call.method) {
          case 'write':
            _store[args['key']! as String] = args['value']! as String;
            return null;
          case 'read':
            return _store[args['key']];
          default:
            return null;
        }
      },
    );
    InjectionContainer.instance.init();
  });

  setUp(_store.clear);

  group('RolePermissions', () {
    test('owner and unnamed roles can do everything; the server still decides', () {
      for (final p in [AgentPosition.owner, AgentPosition.unknown, null]) {
        final perms = RolePermissions(p);
        expect(Capability.values.every(perms.can), isTrue);
        expect(perms.isRestricted, isFalse);
      }
    });

    test('branch manager: requests and team, not wallet, sub-agents or margins', () {
      const m = RolePermissions(AgentPosition.branchManager);
      expect(m.can(Capability.createRequest), isTrue);
      expect(m.can(Capability.branchRequests), isTrue);
      expect(m.can(Capability.team), isTrue);
      expect(m.can(Capability.wallet), isFalse);
      expect(m.can(Capability.subAgents), isFalse);
      expect(m.can(Capability.margins), isFalse);
      expect(m.isRestricted, isTrue);
    });

    test('staff: only creating and following their requests', () {
      const s = RolePermissions(AgentPosition.staff);
      expect([for (final c in Capability.values) if (s.can(c)) c], [Capability.createRequest]);
    });
  });

  group('role-based home', () {
    testWidgets('staff home shows the role, the two actions, why no wallet, and the table', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const RoleHomeScreen(position: AgentPosition.staff)));
      expect(find.text('الرئيسية · موظف'), findsOneWidget);
      expect(find.text('اطلب خدمة'), findsOneWidget);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('المحفظة متاحة لمالك الحساب فقط'), findsOneWidget);
      expect(find.text('الفرق بين الأدوار'), findsOneWidget);
      expect(find.text('المحفظة والشحن'), findsOneWidget);
    });

    testWidgets('the table is read from the same rules the app applies', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const RoleHomeScreen(position: AgentPosition.branchManager)));
      // 5 rows x 3 roles = 15 cells; the allowed ones are exactly what RolePermissions allows.
      var allowed = 0;
      for (final r in roleTableColumns) {
        for (final c in roleTableRows) {
          if (RolePermissions.roleCan(r, c)) {
            allowed++;
          }
        }
      }
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'مسموح'), findsNWidgets(allowed));
      expect(find.text('—'), findsNWidgets(15 - allowed));
    });

    testWidgets('HomeScreen swaps to the role home for a staff session, no wallet call', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(HomeScreen(session: _session('staff'))));
      expect(find.byType(RoleHomeScreen), findsOneWidget);
    });
  });

  group('shell tabs for a restricted role', () {
    testWidgets('wallet and sub-agents are faded and open onto the no-permission view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AgentShell(session: _session('staff'))));
      await tester.pump();
      final faded = tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity == .25).length;
      expect(faded, 2);

      await tester.tap(find.text('المحفظة'));
      await tester.pump();
      await tester.pump();
      expect(find.text('ليس لديك صلاحية'), findsOneWidget);
      expect(find.textContaining('المحفظة متاحة لمالك الحساب فقط'), findsWidgets);

      await tester.tap(find.text('الوكلاء'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('الوكلاء الفرعيون متاحون لمالك الحساب'), findsOneWidget);
    });

    testWidgets('an owner has no faded tab', (tester) async {
      await tester.pumpWidget(_app(Scaffold(bottomNavigationBar: SeenBottomNav(selectedIndex: 0, onSelected: (_) {}))));
      final faded = tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity == .25).length;
      expect(faded, 0);
    });
  });

  group('balance privacy', () {
    test('the preference persists and restores', () async {
      _store.clear();
      final cubit = BalancePrivacyCubit();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isFalse);
      await cubit.setHidden(true);
      expect(_store['hide_balance_default'], 'true');
      final restored = BalancePrivacyCubit();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(restored.state, isTrue);
      await cubit.close();
      await restored.close();
    });

    testWidgets('the balance card starts masked when asked, and follows a late change', (tester) async {
      Widget card(bool hidden) => _app(Scaffold(
            body: SeenBalanceCard(
              initiallyHidden: hidden,
              available: 100,
              hold: 10,
              caption: 'رصيد',
              holdLabel: (a) => 'محجوز $a',
              showSemanticLabel: 'إظهار',
              hideSemanticLabel: 'إخفاء',
            ),
          ));
      await tester.pumpWidget(card(true));
      expect(find.textContaining('100.00'), findsNothing);
      expect(find.textContaining('••••'), findsWidgets);
      await tester.pumpWidget(card(false));
      expect(find.textContaining('100.00'), findsWidgets);
    });
  });

  group('SettingsScreen', () {
    Future<void> open(WidgetTester tester, {RolePermissions permissions = RolePermissions.all, BalancePrivacyCubit? privacy}) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        SettingsScreen(versionLoader: () async => '2.4.0', permissions: permissions),
        providers: [
          BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
          BlocProvider<ThemeModeCubit>(create: (_) => ThemeModeCubit()),
          BlocProvider<BalancePrivacyCubit>(create: (_) => privacy ?? BalancePrivacyCubit()),
        ],
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the current language and theme, the version, and the sections', (tester) async {
      await open(tester);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('تلقائي'), findsOneWidget);
      expect(find.text('الإصدار 2.4.0'), findsOneWidget);
      expect(find.text('تغيير كلمة المرور'), findsOneWidget);
      expect(find.text('الفروع'), findsOneWidget);
    });

    testWidgets('appearance row cycles the theme and shows the new value', (tester) async {
      await open(tester);
      await tester.tap(find.text('المظهر'));
      await tester.pump();
      expect(find.text('تلقائي'), findsNothing);
    });

    testWidgets('the biometric switch is off and unavailable, the balance switch works', (tester) async {
      final privacy = BalancePrivacyCubit();
      addTearDown(() => privacy.close().ignore());
      await open(tester, privacy: privacy);
      expect(find.text('غير متاح بعد'), findsOneWidget);
      final switches = tester.widgetList<SeenSwitch>(find.byType(SeenSwitch)).toList();
      expect(switches.first.onChanged, isNull);
      await tester.tap(find.byType(SeenSwitch).last);
      await tester.pump();
      expect(privacy.state, isTrue);
    });

    testWidgets('rows without a destination say so instead of doing nothing', (tester) async {
      await open(tester);
      await tester.tap(find.text('الفروع'));
      await tester.pump();
      expect(find.text('هذه الخدمة ستتوفر قريبًا.'), findsOneWidget);
    });

    testWidgets('staff do not see Branches', (tester) async {
      await open(tester, permissions: const RolePermissions(AgentPosition.staff));
      expect(find.text('الفروع'), findsNothing);
    });
  });
}
