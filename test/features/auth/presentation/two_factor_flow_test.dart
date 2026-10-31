// Two-step verification (Figma SEC-01..04): the Settings card in each state, and the flow
// that turns it on or issues new recovery codes. Arabic / RTL, 390 wide.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/preferences/balance_privacy_cubit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/domain/entities/two_factor.dart';
import 'package:seen_booking/features/auth/presentation/bloc/two_factor_cubits.dart';
import 'package:seen_booking/features/auth/presentation/screens/two_factor_setup_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/settings_screen.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

import '../../../support/two_factor_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Widget _app(Widget home) => MultiBlocProvider(
      providers: [
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
        BlocProvider<ThemeModeCubit>(create: (_) => ThemeModeCubit()),
        BlocProvider<BalancePrivacyCubit>(create: (_) => BalancePrivacyCubit()),
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
        home: home,
      ),
    );

Future<void> _size(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _openSettings(WidgetTester tester, FakeTwoFactorRepository repo) async {
  await _size(tester);
  await tester.pumpWidget(_app(SettingsScreen(
    versionLoader: () async => '2.4.0',
    permissions: RolePermissions.all,
    createTwoFactorStatusCubit: () => TwoFactorStatusCubit(repo),
  )));
  await tester.pump();
  await tester.pump();
}

Future<void> _openFlow(WidgetTester tester, FakeTwoFactorRepository repo, TwoFactorFlowMode mode,
    {Future<void> Function(List<String>)? saveCodes}) async {
  await _size(tester);
  await tester.pumpWidget(_app(TwoFactorSetupScreen(
    mode: mode,
    createCubit: () => TwoFactorFlowCubit(repo, mode: mode),
    saveCodes: saveCodes,
  )));
  await tester.pump();
  await tester.pump();
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).first, code);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => InjectionContainer.instance.init());

  group('Settings card (SEC-01)', () {
    testWidgets('off: the pitch and the enable button, no recovery rows', (tester) async {
      await _openSettings(tester, FakeTwoFactorRepository());
      expect(find.text(_l10n.secTfaOff), findsOneWidget);
      expect(find.text(_l10n.secTfaPitch), findsOneWidget);
      expect(find.text(_l10n.secTfaEnable), findsOneWidget);
      expect(find.text(_l10n.secRegenerate), findsNothing);
    });

    testWidgets('on: the recovery count and the regenerate row, no disable row', (tester) async {
      final repo = FakeTwoFactorRepository()..statusResult = const Right(TwoFactorStatus(enabled: true, enrolled: true, recoveryCodesLeft: 8));
      await _openSettings(tester, repo);
      expect(find.text(_l10n.secTfaOn), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.secRecoveryCodesLeft(8))), findsOneWidget);
      expect(find.text(_l10n.secRegenerate), findsOneWidget);
      expect(find.text(_l10n.secDisable), findsNothing); // the contract has no such operation
      expect(find.text(_l10n.secTfaEnable), findsNothing);
    });

    testWidgets('enrolled but otpEnabled still false (backend lag): shown as on', (tester) async {
      final repo = FakeTwoFactorRepository()..statusResult = const Right(TwoFactorStatus(enabled: false, enrolled: true, recoveryCodesLeft: 8));
      await _openSettings(tester, repo);
      expect(find.text(_l10n.secTfaOn), findsOneWidget);
    });

    testWidgets('error: a banner in the card with a retry that reads the status again', (tester) async {
      final repo = FakeTwoFactorRepository()..statusResult = const Left(NetworkFailure('offline'));
      await _openSettings(tester, repo);
      expect(find.text(_l10n.secLoadError), findsOneWidget);
      expect(repo.statusCalls, 1);

      repo.statusResult = const Right(TwoFactorStatus(enabled: true, enrolled: true, recoveryCodesLeft: 3));
      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(repo.statusCalls, 2);
      expect(find.text(toArabicIndicDigits(_l10n.secRecoveryCodesLeft(3))), findsOneWidget);
    });
  });

  group('turning it on (SEC-02..04)', () {
    testWidgets('step 1 shows the QR and the secret in groups of four; Next goes to the code', (tester) async {
      final repo = FakeTwoFactorRepository();
      await _openFlow(tester, repo, TwoFactorFlowMode.enable);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.secStepOf(1, 3))), findsOneWidget);

      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      expect(find.text(_l10n.secCodeTitle), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.secStepOf(2, 3))), findsOneWidget);
    });

    testWidgets('step 1 error: its own message, Next stays disabled, retry asks the server again', (tester) async {
      final repo = FakeTwoFactorRepository()..beginResult = const Left(NetworkFailure('offline'));
      await _openFlow(tester, repo, TwoFactorFlowMode.enable);
      expect(find.text(_l10n.secSetupErrorTitle), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      expect(find.text(_l10n.secCodeTitle), findsNothing, reason: 'Next is disabled without a secret');

      repo.beginResult = const Right(testTwoFactorSetup);
      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(repo.beginCalls, 2);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('a right code shows the recovery codes; Done waits for the checkbox and then closes with true', (tester) async {
      final repo = FakeTwoFactorRepository();
      bool? result;
      await _size(tester);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push(MaterialPageRoute<bool>(
            builder: (_) => TwoFactorSetupScreen(mode: TwoFactorFlowMode.enable, createCubit: () => TwoFactorFlowCubit(repo, mode: TwoFactorFlowMode.enable)),
          )),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      await _typeCode(tester, '123456');

      expect(repo.confirmed, ['123456']);
      expect(find.text(_l10n.secCodesTitle), findsOneWidget);
      for (final code in testRecoveryCodes) {
        expect(find.text(code), findsOneWidget);
      }
      expect(find.text(_l10n.secCodesOnce), findsOneWidget);

      await tester.tap(find.text(_l10n.commonDone));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.secCodesTitle), findsOneWidget, reason: 'Done is disabled until the codes are confirmed saved');

      await tester.tap(find.text(_l10n.secSavedCheck));
      await tester.pump();
      await tester.tap(find.text(_l10n.commonDone));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('a wrong code keeps the field and says so; a second try is allowed', (tester) async {
      final repo = FakeTwoFactorRepository()..confirmResult = const Left(ServerFailure('x', code: 'otp_code_invalid'));
      await _openFlow(tester, repo, TwoFactorFlowMode.enable);
      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      await _typeCode(tester, '111111');
      expect(find.text(_l10n.secCodeWrong(0)), findsOneWidget);

      repo.confirmResult = const Right(testRecoveryCodes);
      await _typeCode(tester, '222222');
      expect(repo.confirmed, ['111111', '222222']);
      expect(find.text(_l10n.secCodesTitle), findsOneWidget);
    });

    testWidgets('too many attempts locks the input with the minutes the server gave', (tester) async {
      final repo = FakeTwoFactorRepository()
        ..confirmResult = const Left(ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 15}));
      await _openFlow(tester, repo, TwoFactorFlowMode.enable);
      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      await _typeCode(tester, '111111');
      expect(find.textContaining(_l10n.secLockedTitle), findsOneWidget);
      expect(find.textContaining(toArabicIndicDigits(_l10n.secLockedBody(15))), findsOneWidget);

      await _typeCode(tester, '222222');
      expect(repo.confirmed, ['111111'], reason: 'no second request while locked');
    });

    testWidgets('verifying: the button shows its busy label and a second submit is ignored', (tester) async {
      final repo = FakeTwoFactorRepository()..hold = Completer<void>();
      await _openFlow(tester, repo, TwoFactorFlowMode.enable);
      await tester.tap(find.text(_l10n.commonNext));
      await tester.pump();
      await _typeCode(tester, '123456');
      expect(find.text(_l10n.secVerifying), findsOneWidget);
      await _typeCode(tester, '654321');
      expect(repo.confirmed, ['123456']);

      repo.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text(_l10n.secCodesTitle), findsOneWidget);
    });
  });

  group('new recovery codes (SEC-01 regenerate)', () {
    testWidgets('starts at the code (the user already has a device), never begins an enrollment', (tester) async {
      final repo = FakeTwoFactorRepository();
      await _openFlow(tester, repo, TwoFactorFlowMode.regenerate);
      expect(find.text(_l10n.secCodeTitle), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.secStepOf(1, 3))), findsNothing);
      await _typeCode(tester, '123456');
      expect(repo.regenerated, ['123456']);
      expect(repo.confirmed, isEmpty);
      expect(repo.beginCalls, 0);
      expect(find.text(_l10n.secCodesTitle), findsOneWidget);
    });
  });
}
