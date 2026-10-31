// AUTH-15 change password and AUTH-16 change phone number. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/account_security.dart';
import 'package:seen_booking/features/auth/domain/repositories/account_security_repository.dart';
import 'package:seen_booking/features/auth/presentation/bloc/account_security_cubits.dart';
import 'package:seen_booking/features/auth/presentation/screens/change_password_screen.dart';
import 'package:seen_booking/features/auth/presentation/screens/change_phone_screen.dart';

class _Repo implements AccountSecurityRepository {
  Failure? passwordFailure;
  Failure? requestFailure;
  Failure? confirmFailure;
  final calls = <String>[];

  @override
  Future<Either<Failure, void>> changePassword({required String current, required String next}) async {
    calls.add('pw:$current:$next');
    return passwordFailure == null ? const Right(null) : Left(passwordFailure!);
  }

  @override
  Future<Either<Failure, String>> currentPhoneMasked() async => const Right('+967 77 ••• 0700');

  @override
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone) async {
    calls.add('request:$newPhone');
    return requestFailure == null
        ? const Right(PhoneChangeChallenge(challengeToken: 'tok', resendCooldownSeconds: 30))
        : Left(requestFailure!);
  }

  @override
  Future<Either<Failure, PhoneChangeChallenge>> resendPhoneChange(String challengeToken) async {
    calls.add('resend:$challengeToken');
    return const Right(PhoneChangeChallenge(challengeToken: 'tok2', resendCooldownSeconds: 30));
  }

  @override
  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code}) async {
    calls.add('confirm:$challengeToken:$code');
    return confirmFailure == null ? const Right(null) : Left(confirmFailure!);
  }
}

Widget _app(Widget home) => MaterialApp(
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

void main() {
  group('AccountIssue', () {
    test('maps backend codes', () {
      AccountIssueKind kind(String code) => AccountIssue.from(ServerFailure('x', code: code)).kind;
      expect(kind('current_password_invalid'), AccountIssueKind.wrongCurrentPassword);
      expect(kind('password_unchanged'), AccountIssueKind.passwordReused);
      expect(kind('PHONE_ALREADY_REGISTERED'), AccountIssueKind.phoneTaken);
      expect(kind('OTP_INVALID'), AccountIssueKind.wrongCode);
      expect(kind('password_weak'), AccountIssueKind.weakPassword);
      expect(kind('too_many_attempts'), AccountIssueKind.rateLimited);
      expect(kind('nonsense'), AccountIssueKind.generic);
      expect(AccountIssue.from(const NetworkFailure('off')).kind, AccountIssueKind.offline);
    });
  });

  group('ChangePasswordScreen', () {
    Future<void> open(WidgetTester tester, _Repo repo) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(ChangePasswordScreen(createCubit: () => ChangePasswordCubit(repo))));
      await tester.pump();
    }

    Future<void> fill(WidgetTester tester, {String current = 'Current@1', String next = 'NewPass@123', String? confirm}) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), current);
      await tester.enterText(fields.at(1), next);
      await tester.enterText(fields.at(2), confirm ?? next);
      await tester.pump();
    }

    testWidgets('Save stays off until the current is filled, the rules pass and the two match', (tester) async {
      final repo = _Repo();
      await open(tester, repo);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(repo.calls, isEmpty);
      await fill(tester, confirm: 'Different@1');
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(repo.calls, isEmpty);
      await fill(tester);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, ['pw:Current@1:NewPass@123']);
    });

    testWidgets('success: the banner says other devices are signed out, and the fields are cleared', (tester) async {
      final repo = _Repo();
      await open(tester, repo);
      await fill(tester);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تم تغيير كلمة المرور. سنُخرجك من الأجهزة الأخرى.'), findsOneWidget);
      final texts = tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text);
      expect(texts.every((t) => t.isEmpty), isTrue);
    });

    testWidgets('wrong current password marks that field only', (tester) async {
      final repo = _Repo()..passwordFailure = const ServerFailure('x', code: AccountIssue.wrongCurrentPasswordCode);
      await open(tester, repo);
      await fill(tester);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      await tester.pump();
      expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
      expect(find.text('تم تغيير كلمة المرور. سنُخرجك من الأجهزة الأخرى.'), findsNothing);
      // Typing again clears the mark.
      await tester.enterText(find.byType(TextFormField).first, 'Other@123');
      await tester.pump();
      expect(find.text('كلمة المرور الحالية غير صحيحة'), findsNothing);
    });

    testWidgets('a reused password shows a banner', (tester) async {
      final repo = _Repo()..passwordFailure = const ServerFailure('x', code: AccountIssue.passwordReusedCode);
      await open(tester, repo);
      await fill(tester);
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      await tester.pump();
      expect(find.text('لا يمكن استخدام كلمة مرور سابقة.'), findsOneWidget);
    });
  });

  group('ChangePhoneScreen', () {
    Future<void> open(WidgetTester tester, _Repo repo) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(ChangePhoneScreen(createCubit: () => ChangePhoneCubit(repo))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the masked current number; a bad new number is refused locally', (tester) async {
      final repo = _Repo();
      await open(tester, repo);
      expect(find.textContaining('0700'), findsOneWidget);
      await tester.tap(find.text('تأكيد الرقم'));
      await tester.pump();
      expect(find.text('أدخل رقم جوال صحيحًا.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('confirm sends the code to the E.164 number, shows the code boxes, then verifies', (tester) async {
      final repo = _Repo();
      await open(tester, repo);
      await tester.enterText(find.byType(TextFormField).last, '731232215');
      await tester.tap(find.text('تأكيد الرقم'));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, ['request:+967731232215']);
      expect(find.text('أدخل الرمز المرسل إلى الرقم الجديد'), findsOneWidget);
      expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.pump();
      expect(repo.calls.last, 'confirm:tok:123456');
    });

    testWidgets('a number used by another account shows the banner', (tester) async {
      final repo = _Repo()..requestFailure = const ServerFailure('x', code: AccountIssue.phoneTakenCode);
      await open(tester, repo);
      await tester.enterText(find.byType(TextFormField).last, '731232215');
      await tester.tap(find.text('تأكيد الرقم'));
      await tester.pump();
      await tester.pump();
      expect(find.text('الرقم الجديد مستخدم في حساب آخر.'), findsOneWidget);
      expect(find.text('أدخل الرمز المرسل إلى الرقم الجديد'), findsNothing);
    });

    testWidgets('a wrong code shows the attempts left; editing the number starts over', (tester) async {
      final repo = _Repo()
        ..confirmFailure = const ServerFailure('x', code: AccountIssue.wrongCodeCode, details: {'attemptsLeft': 2});
      await open(tester, repo);
      await tester.enterText(find.byType(TextFormField).last, '731232215');
      await tester.tap(find.text('تأكيد الرقم'));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(EditableText).last, '000111');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('الرمز غير صحيح'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '731232216');
      await tester.pump();
      expect(find.text('أدخل الرمز المرسل إلى الرقم الجديد'), findsNothing);
      expect(find.textContaining('الرمز غير صحيح'), findsNothing);
    });

    testWidgets('success leaves the screen with a confirmation', (tester) async {
      final repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ChangePhoneScreen(createCubit: () => ChangePhoneCubit(repo))),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '731232215');
      await tester.tap(find.text('تأكيد الرقم'));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(ChangePhoneScreen), findsNothing);
      expect(find.textContaining('تم تغيير رقم الجوال'), findsOneWidget);
    });
  });
}
