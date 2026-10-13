// Phase 3F: Welcome -> Create agency account (15) -> Pending approval (16),
// the account hub (14) sign-out confirmation and the notification day groups.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seen_booking/app.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_state.dart';
import 'package:seen_booking/features/home/presentation/screens/account_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/notifications_screen.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    InjectionContainer.instance.init();
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App(splashMinDuration: Duration.zero));
    await tester.pumpAndSettle();
  }

  group('create agency account', () {
    testWidgets('empty submit shows validation and stays on the form', (tester) async {
      await boot(tester);
      await tester.ensureVisible(find.text('إنشاء حساب وكالة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء حساب وكالة'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
      expect(find.text('حسابك قيد المراجعة'), findsNothing);
    });

    testWidgets('a valid form moves to pending approval; system back leaves it', (tester) async {
      await boot(tester);
      await tester.ensureVisible(find.text('إنشاء حساب وكالة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء حساب وكالة'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'وكالة النور');
      await tester.enterText(fields.at(1), 'أحمد محمد علي');
      await tester.enterText(fields.at(2), '771234567');
      await tester.enterText(fields.at(3), 'agency@example.com');
      await tester.enterText(fields.at(4), 'صنعاء');
      await tester.enterText(fields.at(5), 'CR-12345');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(find.text('حسابك قيد المراجعة'), findsOneWidget);
      expect(find.text('مراجعة المستندات'), findsOneWidget);

      // The system back gesture leaves the pending screen (back to Welcome).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('حسابك قيد المراجعة'), findsNothing);
    });
  });

  testWidgets('account screen: sign out asks first and cancel keeps the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = InjectionContainer.instance.createAuthBloc();
    addTearDown(() => auth.close().ignore());
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider(create: (_) => LocaleCubit()),
        BlocProvider(create: (_) => ThemeModeCubit()),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: AccountScreen(versionLoader: () async => '2.4.0'),
      ),
    ));
    await tester.pumpAndSettle();
    final before = auth.state;
    expect(find.textContaining('2.4.0'), findsOneWidget);
    expect(find.textContaining('الإصدار'), findsOneWidget);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsNothing);
    expect(find.text('حسابي'), findsOneWidget);
    expect(auth.state, before);
    expect(auth.state, isNot(isA<AuthLoading>()));
  });

  test('notification groups bucket by calendar day', () {
    final now = DateTime(2026, 10, 13, 9);
    expect(notificationGroupOf(DateTime(2026, 10, 13, 0, 5), now), NotificationGroup.today);
    expect(notificationGroupOf(DateTime(2026, 10, 12, 23, 59), now), NotificationGroup.yesterday);
    expect(notificationGroupOf(DateTime(2026, 10, 11, 12), now), NotificationGroup.earlier);
    expect(notificationGroupOf(DateTime(2026, 10, 14), now), NotificationGroup.today); // clock skew
  });
}
