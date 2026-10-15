// Forgot-password flow (Figma AUTH-01 … AUTH-04): bloc rules over a fake
// repository, and the screens end to end. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/password_recovery.dart';
import 'package:seen_booking/features/auth/domain/repositories/password_recovery_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/password_recovery_usecases.dart';
import 'package:seen_booking/features/auth/presentation/bloc/password_recovery_bloc.dart';
import 'package:seen_booking/features/auth/presentation/screens/forgot_password_flow.dart';

const _challenge = RecoveryChallenge(
  challengeToken: 't1',
  maskedDestination: '+967 77 ••• 0700',
  resendCooldownSeconds: 45,
);

class _FakeRepo implements PasswordRecoveryRepository {
  Either<Failure, RecoveryChallenge> requestResult = const Right(_challenge);
  Either<Failure, String> verifyResult = const Right('reset-1');
  Either<Failure, void> resetResult = const Right(null);
  int requests = 0;
  int resends = 0;
  String? lastIdentifier;
  String? lastPassword;

  @override
  Future<Either<Failure, RecoveryChallenge>> requestCode({required String identifier}) async {
    requests++;
    lastIdentifier = identifier;
    return requestResult;
  }

  @override
  Future<Either<Failure, RecoveryChallenge>> resendCode({required String challengeToken}) async {
    resends++;
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code}) async =>
      verifyResult;

  @override
  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword}) async {
    lastPassword = newPassword;
    return resetResult;
  }
}

PasswordRecoveryBloc _bloc(_FakeRepo r) => PasswordRecoveryBloc(
      requestCode: RequestPasswordResetCodeUseCase(r),
      resendCode: ResendPasswordResetCodeUseCase(r),
      verifyCode: VerifyPasswordResetCodeUseCase(r),
      resetPassword: ResetPasswordUseCase(r),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  // Let the step cross-fade finish (the old step leaves the tree).
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('RecoveryIssue.from', () {
    test('maps backend codes and their details', () {
      expect(RecoveryIssue.from(const NetworkFailure('x')).kind, RecoveryIssueKind.offline);
      expect(
        RecoveryIssue.from(const ServerFailure('x', code: RecoveryIssue.accountNotFound)).kind,
        RecoveryIssueKind.unknownAccount,
      );
      final limited = RecoveryIssue.from(
        const ServerFailure('x', code: RecoveryIssue.rateLimitedCode, details: {'retryAfterSeconds': 299}),
      );
      expect((limited.kind, limited.seconds), (RecoveryIssueKind.rateLimited, 299));
      final wrong = RecoveryIssue.from(
        const ServerFailure('x', code: RecoveryIssue.wrongCodeCode, details: {'attemptsLeft': 2}),
      );
      expect((wrong.kind, wrong.attemptsLeft), (RecoveryIssueKind.wrongCode, 2));
      expect(RecoveryIssue.from(const ServerFailure('boom')).kind, RecoveryIssueKind.generic);
    });
  });

  group('PasswordRecoveryBloc', () {
    test('request → otp → new password → done', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);

      bloc.add(const RecoveryCodeRequested('+967771234567'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.otp);
      expect(bloc.state.challenge, _challenge);
      expect(bloc.state.codesSent, 1);

      bloc.add(const RecoveryCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.newPassword);
      expect(bloc.state.resetToken, 'reset-1');

      bloc.add(const RecoveryPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.done);
      expect(repo.lastPassword, 'Abcdef12');
    });

    test('an unknown account stays on the request step with an issue', () async {
      final repo = _FakeRepo()
        ..requestResult = const Left(ServerFailure('x', code: RecoveryIssue.accountNotFound));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);

      bloc.add(const RecoveryCodeRequested('+967771234500'));
      final s = await bloc.stream.firstWhere((s) => !s.busy && s.issue != null);
      expect(s.step, RecoveryStep.request);
      expect(s.issue!.kind, RecoveryIssueKind.unknownAccount);
    });

    test('a wrong code keeps the otp step and carries the attempts left; resend bumps codesSent', () async {
      final repo = _FakeRepo()
        ..verifyResult = const Left(
          ServerFailure('x', code: RecoveryIssue.wrongCodeCode, details: {'attemptsLeft': 2}),
        );
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RecoveryCodeRequested('+967771234567'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.otp);

      bloc.add(const RecoveryCodeSubmitted('111111'));
      final wrong = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(wrong.step, RecoveryStep.otp);
      expect(wrong.issue!.attemptsLeft, 2);

      bloc.add(const RecoveryResendRequested());
      final resent = await bloc.stream.firstWhere((s) => s.codesSent == 2);
      expect(resent.issue, isNull);
      expect(repo.resends, 1);
    });

    test('a reused password stays on the password step; back returns to the request step', () async {
      final repo = _FakeRepo()
        ..resetResult = const Left(ServerFailure('x', code: RecoveryIssue.passwordReusedCode));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RecoveryCodeRequested('+967771234567'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.otp);
      bloc.add(const RecoveryCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RecoveryStep.newPassword);

      bloc.add(const RecoveryPasswordSubmitted('Abcdef12'));
      final s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.step, RecoveryStep.newPassword);
      expect(s.issue!.kind, RecoveryIssueKind.passwordReused);

      bloc.add(const RecoveryBackPressed());
      expect((await bloc.stream.firstWhere((s) => s.step == RecoveryStep.request)).issue, isNull);
    });
  });

  group('ForgotPasswordFlow', () {
    late _FakeRepo repo;

    Future<void> open(WidgetTester tester, {required VoidCallback onExit}) async {
      repo = _FakeRepo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: ForgotPasswordFlow(onExit: onExit, createBloc: () => _bloc(repo)),
      ));
      await tester.pump();
    }

    testWidgets('an invalid phone shows the validation error and sends nothing', (tester) async {
      await open(tester, onExit: () {});
      await tester.tap(find.text('إرسال الرمز'));
      await tester.pump();
      expect(find.text('أدخل رقم جوال صحيحًا.'), findsOneWidget);
      expect(repo.requests, 0);
    });

    testWidgets('the whole happy path, ending on the confirmation and back to login', (tester) async {
      var exited = 0;
      await open(tester, onExit: () => exited++);

      await tester.enterText(find.byType(TextFormField).first, '771234567');
      await tester.tap(find.text('إرسال الرمز'));
      await _settle(tester);
      expect(repo.lastIdentifier, '+967771234567');
      expect(find.text('أدخل الرمز المرسل'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await _settle(tester);
      expect(find.text('اختر كلمة مرور جديدة'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Abcdef12');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Abcdef12');
      await tester.pump();
      await tester.tap(find.text('حفظ كلمة المرور'));
      await _settle(tester);
      expect(repo.lastPassword, 'Abcdef12');
      expect(find.text('تم تغيير كلمة المرور'), findsOneWidget);

      await tester.tap(find.text('العودة لتسجيل الدخول'));
      expect(exited, 1);
    });

    testWidgets('an unknown account shows the red message and the support / create links', (tester) async {
      await open(tester, onExit: () {});
      repo.requestResult = const Left(ServerFailure('x', code: RecoveryIssue.accountNotFound));
      await tester.enterText(find.byType(TextFormField).first, '771234511');
      await tester.tap(find.text('إرسال الرمز'));
      await _settle(tester);
      expect(find.text('لا يوجد حساب مسجّل بهذا الرقم. تأكد من الرقم أو أنشئ حساب وكالة.'), findsOneWidget);
      expect(find.text('تواصل مع الدعم'), findsOneWidget);
    });

    testWidgets('the save button stays disabled until the rules pass and the passwords match', (tester) async {
      await open(tester, onExit: () {});
      await tester.enterText(find.byType(TextFormField).first, '771234567');
      await tester.tap(find.text('إرسال الرمز'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await _settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'abc');
      await tester.enterText(fields.at(1), 'abc');
      await tester.pump();
      await tester.tap(find.text('حفظ كلمة المرور'));
      await _settle(tester);
      expect(find.text('تم تغيير كلمة المرور'), findsNothing);

      await tester.enterText(fields.at(0), 'Abcdef12');
      await tester.enterText(fields.at(1), 'Abcdef13');
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    });
  });
}
