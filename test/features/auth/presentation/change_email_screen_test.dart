// Change e-mail (Figma ACC-08..10): the Settings row, the form and its errors, and the
// "check your e-mail" state. Arabic / RTL, 390 wide.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/locale_cubit.dart';
import 'package:seen_booking/core/preferences/balance_privacy_cubit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/theme_mode_cubit.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/presentation/bloc/email_change_cubit.dart';
import 'package:seen_booking/features/auth/presentation/bloc/two_factor_cubits.dart';
import 'package:seen_booking/features/auth/presentation/screens/change_email_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/settings_screen.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

import '../../../support/email_change_fakes.dart';
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

Future<void> _open(WidgetTester tester, FakeEmailChangeRepository repo, {Future<void> Function()? openMailApp}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(ChangeEmailScreen(createCubit: () => EmailChangeCubit(repo), openMailApp: openMailApp)));
  await tester.pump();
  await tester.pump();
}

Future<void> _fill(WidgetTester tester, {String email = 'new@agency.com', String password = 'Secret@123'}) async {
  final fields = find.byType(TextField);
  // Order: current e-mail (read-only), new e-mail, password.
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.text(_l10n.accSend));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => InjectionContainer.instance.init());

  testWidgets('the Settings row sits under change password and shows the current address', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(SettingsScreen(
      versionLoader: () async => '2.4.0',
      permissions: RolePermissions.all,
      createTwoFactorStatusCubit: () => TwoFactorStatusCubit(FakeTwoFactorRepository()),
      createEmailChangeCubit: () => EmailChangeCubit(FakeEmailChangeRepository()),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text(_l10n.accChangeEmail), findsOneWidget);
    expect(find.textContaining('owner@agency.com'), findsOneWidget);
    final password = tester.getTopLeft(find.text('تغيير كلمة المرور')).dy;
    final email = tester.getTopLeft(find.text(_l10n.accChangeEmail)).dy;
    final phone = tester.getTopLeft(find.text('تغيير رقم الجوال')).dy;
    expect(password < email && email < phone, isTrue);
  });

  testWidgets('the form shows the current address read-only; Send stays disabled until both fields are filled', (tester) async {
    final repo = FakeEmailChangeRepository();
    await _open(tester, repo);
    expect(find.text('owner@agency.com'), findsOneWidget);
    await tester.tap(find.text(_l10n.accSend));
    await tester.pump();
    expect(repo.requests, isEmpty);
  });

  testWidgets('an invalid address is refused on the spot, without a request', (tester) async {
    final repo = FakeEmailChangeRepository();
    await _open(tester, repo);
    await _fill(tester, email: 'not-an-email');
    await _send(tester);
    expect(find.text(_l10n.accInvalidEmail), findsOneWidget);
    expect(repo.requests, isEmpty);
  });

  testWidgets('the current address is refused as the new one (case-insensitive)', (tester) async {
    final repo = FakeEmailChangeRepository();
    await _open(tester, repo);
    await _fill(tester, email: 'OWNER@agency.com');
    await _send(tester);
    expect(find.text(_l10n.accSameEmail), findsOneWidget);
    expect(repo.requests, isEmpty);
  });

  testWidgets('a wrong password is flagged on the password field and typing clears it', (tester) async {
    final repo = FakeEmailChangeRepository()..requestResult = const Left(ServerFailure('x', code: 'current_password_invalid'));
    await _open(tester, repo);
    await _fill(tester);
    await _send(tester);
    expect(find.text(_l10n.accWrongPassword(0)), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'Other@1234');
    await tester.pump();
    expect(find.text(_l10n.accWrongPassword(0)), findsNothing);
  });

  testWidgets('too many attempts: a banner with the minutes, the fields and Send are disabled', (tester) async {
    final repo = FakeEmailChangeRepository()
      ..requestResult = const Left(ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 10}));
    await _open(tester, repo);
    await _fill(tester);
    await _send(tester);
    expect(find.textContaining(_l10n.accTooManyTitle), findsOneWidget);
    expect(find.textContaining(toArabicIndicDigits(_l10n.accTooManyBody(10))), findsOneWidget);
    await tester.tap(find.text(_l10n.accSend));
    await tester.pump();
    expect(repo.requests, hasLength(1));
  });

  testWidgets('sending: the busy label shows and a second tap sends nothing more', (tester) async {
    final repo = FakeEmailChangeRepository()..hold = Completer<void>();
    await _open(tester, repo);
    await _fill(tester);
    await _send(tester);
    expect(find.text(_l10n.accSending), findsOneWidget);
    await tester.tap(find.text(_l10n.accSending));
    await tester.pump();
    expect(repo.requests, hasLength(1));
    repo.hold!.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('success: "check your e-mail" with the new address, Open email, and a way back to edit it', (tester) async {
    final repo = FakeEmailChangeRepository();
    var opened = 0;
    await _open(tester, repo, openMailApp: () async => opened++);
    await _fill(tester);
    await _send(tester);
    expect(repo.requests.single.newEmail, 'new@agency.com');
    expect(find.text(_l10n.accCheckTitle), findsOneWidget);
    expect(find.text('new@agency.com'), findsOneWidget);
    expect(find.text(_l10n.accResend), findsNothing, reason: 'the server has no resend');

    await tester.tap(find.text(_l10n.accOpenMail));
    expect(opened, 1);

    await tester.tap(find.text(_l10n.accEditEmail));
    await tester.pump();
    expect(find.text(_l10n.accSend), findsOneWidget);
    expect(find.widgetWithText(TextField, 'new@agency.com'), findsOneWidget, reason: 'the address stays in the field');
  });

  testWidgets('offline shows the connection message and keeps the form', (tester) async {
    final repo = FakeEmailChangeRepository()..requestResult = const Left(NetworkFailure('offline'));
    await _open(tester, repo);
    await _fill(tester);
    await _send(tester);
    expect(find.text(_l10n.accSendFailed), findsOneWidget);
    expect(find.text(_l10n.accSend), findsOneWidget);
  });
}
