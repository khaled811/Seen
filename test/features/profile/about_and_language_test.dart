// ACC-05 (language switch confirmation) and ACC-06 (about / legal). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/preferences/balance_privacy_cubit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/profile/presentation/screens/about_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/settings_screen.dart';
import 'package:seen_booking/features/system_status/domain/entities/app_status.dart';
import 'package:seen_booking/features/system_status/domain/repositories/app_status_repository.dart';
import 'package:seen_booking/features/system_status/domain/services/store_launcher.dart';
import 'package:seen_booking/features/system_status/domain/usecases/system_status_usecases.dart';
import 'package:seen_booking/features/system_status/presentation/bloc/app_status_cubit.dart';
import 'package:seen_booking/core/error/failure.dart';

class _Launcher implements StoreLauncher {
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

class _StatusRepo implements AppStatusRepository {
  @override
  Future<Either<Failure, AppStatus>> fetch() async => const Right(AppStatus(storeUrl: 'https://store.example/app'));
}

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

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  group('language switch confirmation (ACC-05)', () {
    Future<LocaleCubit> open(WidgetTester tester) async {
      final locale = LocaleCubit();
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => locale.close().ignore());
      await tester.pumpWidget(_app(
        SettingsScreen(versionLoader: () async => '2.4.0'),
        providers: [
          BlocProvider<LocaleCubit>.value(value: locale),
          BlocProvider<ThemeModeCubit>(create: (_) => ThemeModeCubit()),
          BlocProvider<BalancePrivacyCubit>(create: (_) => BalancePrivacyCubit()),
        ],
      ));
      await tester.pump();
      return locale;
    }

    testWidgets('tapping Language asks first; Cancel changes nothing', (tester) async {
      final locale = await open(tester);
      await tester.tap(find.text('اللغة'));
      await tester.pumpAndSettle();
      expect(find.text('التبديل إلى English؟'), findsOneWidget);
      expect(find.textContaining('اليسار → اليمين'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(locale.state.languageCode, 'ar');
      expect(find.text('التبديل إلى English؟'), findsNothing);
    });

    testWidgets('Switch confirms and changes the language', (tester) async {
      final locale = await open(tester);
      await tester.tap(find.text('اللغة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تبديل'));
      await tester.pump();
      expect(locale.state.languageCode, 'en');
    });
  });

  group('about (ACC-06)', () {
    testWidgets('shows version with build, the links, and the copyright year', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AboutScreen(
        versionLoader: () async => (version: '2.4.0', build: '318'),
        now: DateTime(2026, 10, 18),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('حول التطبيق'), findsOneWidget);
      expect(find.textContaining('2.4.0 (318)'), findsOneWidget);
      expect(find.text('الشروط والأحكام'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('تراخيص البرمجيات مفتوحة المصدر'), findsOneWidget);
      expect(find.text('قيّم التطبيق'), findsOneWidget);
      expect(find.textContaining('٢٠٢٦'), findsOneWidget);
    });

    testWidgets('Rate opens the store link; without one it says so', (tester) async {
      final launcher = _Launcher();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AboutScreen(
        versionLoader: () async => (version: '2.4.0', build: '318'),
        launcher: launcher,
        storeUrl: 'https://store.example/app',
      )));
      await tester.pump();
      await tester.tap(find.text('قيّم التطبيق'));
      await tester.pump();
      expect(launcher.opened, ['https://store.example/app']);

      final none = _Launcher();
      await tester.pumpWidget(_app(AboutScreen(versionLoader: () async => (version: '1', build: '1'), launcher: none)));
      await tester.pump();
      await tester.tap(find.text('قيّم التطبيق'));
      await tester.pump();
      await tester.pump();
      expect(none.opened, isEmpty);
      expect(find.text('تعذّر فتح المتجر.'), findsOneWidget);
    });

    testWidgets('the store link comes from the last app-status answer', (tester) async {
      final status = AppStatusCubit(getStatus: GetAppStatusUseCase(_StatusRepo()), currentVersion: () async => '1.0.0');
      addTearDown(() => status.close().ignore());
      await status.check();
      expect(status.storeUrl, 'https://store.example/app');
      final launcher = _Launcher();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        AboutScreen(versionLoader: () async => (version: '1', build: '1'), launcher: launcher),
        providers: [BlocProvider<AppStatusCubit>.value(value: status)],
      ));
      await tester.pump();
      await tester.tap(find.text('قيّم التطبيق'));
      await tester.pump();
      expect(launcher.opened, ['https://store.example/app']);
    });

    testWidgets('the licences row opens the licence page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AboutScreen(versionLoader: () async => (version: '1', build: '1'))));
      await tester.pump();
      await tester.tap(find.text('تراخيص البرمجيات مفتوحة المصدر'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  testWidgets('Settings "About" opens the About screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(
      SettingsScreen(versionLoader: () async => '2.4.0'),
      providers: [
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
        BlocProvider<ThemeModeCubit>(create: (_) => ThemeModeCubit()),
        BlocProvider<BalancePrivacyCubit>(create: (_) => BalancePrivacyCubit()),
      ],
    ));
    await tester.pump();
    await tester.pump();
    // The screen grew with the security rows: scroll to the row first.
    await tester.ensureVisible(find.text('حول التطبيق'));
    await tester.pump();
    await tester.tap(find.text('حول التطبيق'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
  });
}
