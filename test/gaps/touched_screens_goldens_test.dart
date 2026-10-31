// Loaded-state goldens of the existing screens the GAPS features add one element to
// (design/gaps SPEC §0.2). The baselines were captured BEFORE each screen was edited; after the
// edit the only difference allowed is the added element, so a baseline is regenerated
// deliberately (`--update-goldens`), once, and the diff is reviewed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/preferences/balance_privacy_cubit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:seen_booking/features/auth/presentation/bloc/email_change_cubit.dart';
import 'package:seen_booking/features/auth/presentation/bloc/two_factor_cubits.dart';
import 'package:seen_booking/features/home/presentation/screens/account_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/settings_screen.dart';

import '../support/email_change_fakes.dart';
import '../support/two_factor_fakes.dart';

const _surface = Size(390, 1000);

Widget _app(Widget home) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => InjectionContainer.instance.createAuthBloc()),
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
        BlocProvider<ThemeModeCubit>(create: (_) => ThemeModeCubit()),
        BlocProvider<BalancePrivacyCubit>(create: (_) => BalancePrivacyCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
      ),
    );

Future<void> _shot(WidgetTester tester, String name, Widget screen) async {
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(screen));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await screenMatchesGolden(tester, name);
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await loadAppFonts();
    InjectionContainer.instance.init();
  });

  testGoldens(
    'settings',
    (t) => _shot(
      t,
      'settings',
      SettingsScreen(
        versionLoader: () async => '2.4.0',
        permissions: RolePermissions.all,
        createTwoFactorStatusCubit: () => TwoFactorStatusCubit(FakeTwoFactorRepository()),
        createEmailChangeCubit: () => EmailChangeCubit(FakeEmailChangeRepository()),
      ),
    ),
  );

  testGoldens(
    'account',
    (t) => _shot(t, 'account', AccountScreen(pollUnread: false, versionLoader: () async => '2.4.0')),
  );
}
