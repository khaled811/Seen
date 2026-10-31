// The second sign-in step against the real contract: the code comes from an
// authenticator app (nothing to resend), a recovery code is the way out when the
// phone is lost, and the server's own words never reach the screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/auth_attempt_result.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';
import 'package:seen_booking/features/auth/domain/repositories/auth_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/get_persisted_session_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/login_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/logout_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/resend_otp_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_event.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_state.dart';
import 'package:seen_booking/features/auth/presentation/screens/otp_verification_screen.dart';

class _Repo implements AuthRepository {
  Either<Failure, AuthAttemptResult> loginResult = const Right(
    AuthOtpChallenge(challengeToken: 'ch-1', resendCooldownSeconds: 0, canResend: false),
  );
  Either<Failure, UserSession> otpResult = const Left(ServerFailure('x', code: 'otp_code_invalid'));
  final codes = <String>[];
  int resends = 0;

  @override
  Future<Either<Failure, AuthAttemptResult>> login({required String identifier, required String password}) async =>
      loginResult;

  @override
  Future<Either<Failure, UserSession>> verifyOtp({required String challengeToken, required String code}) async {
    codes.add(code);
    return otpResult;
  }

  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({required String challengeToken}) async {
    resends++;
    return const Left(ServerFailure('x', code: 'resend_unsupported'));
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<UserSession?> getPersistedSession() async => null;
}

AuthBloc _bloc(_Repo repo) => AuthBloc(
      loginUseCase: LoginUseCase(repo),
      verifyOtpUseCase: VerifyOtpUseCase(repo),
      resendOtpUseCase: ResendOtpUseCase(repo),
      logoutUseCase: LogoutUseCase(repo),
      getPersistedSessionUseCase: GetPersistedSessionUseCase(repo),
      authSessionController: AuthSessionController(),
    );

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

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('AuthBloc', () {
    test('an authenticator challenge keeps canResend=false through a wrong code', () async {
      final repo = _Repo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await _settle();
      expect((bloc.state as AuthOtpRequired).canResend, isFalse);

      bloc.add(const AuthOtpSubmitted(code: '000000'));
      await _settle();
      final failure = bloc.state as AuthFailure;
      expect(failure.stage, AuthFailureStage.otp);
      expect(failure.canResend, isFalse);
      expect((failure.cause as ServerFailure).code, 'otp_code_invalid');
    });

    test('a forgotten challenge sends the person back to Login with its own message', () async {
      final repo = _Repo()..otpResult = const Left(ServerFailure('x', code: 'otp_challenge_invalid'));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await _settle();

      bloc.add(const AuthOtpSubmitted(code: '123456'));
      await _settle();

      final failure = bloc.state as AuthFailure;
      expect((failure.stage, failure.reason), (AuthFailureStage.login, LoginFailureReason.verificationExpired));
    });

    test('a phone number typed at sign-in becomes the e-mail-required reason', () async {
      final repo = _Repo()
        ..loginResult = const Left(ValidationFailure('x', fieldErrors: {
          'email': ['email_required'],
        }));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);

      bloc.add(const AuthLoginSubmitted(identifier: '+967771234567', password: 'pw'));
      await _settle();

      expect((bloc.state as AuthFailure).reason, LoginFailureReason.emailRequired);
    });

    test('an account that needs web enrollment becomes the enrollment reason, at login and at the second step', () async {
      final repo = _Repo()..loginResult = const Left(ServerFailure('x', code: 'enrollment_link_required'));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await _settle();
      expect((bloc.state as AuthFailure).reason, LoginFailureReason.enrollmentLinkRequired);

      repo.loginResult = const Right(AuthOtpChallenge(challengeToken: 'c', resendCooldownSeconds: 0, canResend: false));
      repo.otpResult = const Left(ServerFailure('x', code: 'enrollment_link_required'));
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await _settle();
      bloc.add(const AuthOtpSubmitted(code: '123456'));
      await _settle();
      expect((bloc.state as AuthFailure).reason, LoginFailureReason.enrollmentLinkRequired);
    });
  });

  group('OtpVerificationScreen without resend', () {
    Future<(_Repo, AuthBloc)> open(WidgetTester tester) async {
      final repo = _Repo();
      final bloc = _bloc(repo);
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(const OtpVerificationScreen(resendCooldownSeconds: 0, canResend: false)),
      ));
      await tester.pump();
      return (repo, bloc);
    }

    testWidgets('says the code comes from the authenticator app and offers no resend', (tester) async {
      await open(tester);

      expect(find.text('أدخل الرمز المكوّن من ٦ أرقام من تطبيق المصادقة.'), findsOneWidget);
      expect(find.text('إعادة إرسال الرمز'), findsNothing);
      expect(find.text('استخدام رمز الاسترداد'), findsOneWidget);
    });

    testWidgets('a recovery code can be typed and is sent as it is', (tester) async {
      final (repo, bloc) = await open(tester);
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await tester.runAsync(_settle);

      await tester.tap(find.text('استخدام رمز الاسترداد'));
      await tester.pump();
      expect(find.text('استخدام رمز تطبيق المصادقة'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcd-efgh-ijkl');
      await tester.tap(find.text('تأكيد'));
      await tester.runAsync(_settle);
      await tester.pump();

      expect(repo.codes, ['abcd-efgh-ijkl']);
    });

    testWidgets('a too-short recovery code is not sent', (tester) async {
      final (repo, bloc) = await open(tester);
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await tester.runAsync(_settle);
      await tester.tap(find.text('استخدام رمز الاسترداد'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'abcd');
      await tester.tap(find.text('تأكيد'));
      await tester.runAsync(_settle);

      expect(repo.codes, isEmpty);
    });

    testWidgets('a wrong code shows our own message, not the server text', (tester) async {
      final (repo, bloc) = await open(tester);
      repo.otpResult = const Left(ServerFailure('server words the user must not see', code: 'otp_code_invalid'));
      bloc.add(const AuthLoginSubmitted(identifier: 'a@b.test', password: 'pw'));
      await tester.runAsync(_settle);
      await tester.tap(find.text('استخدام رمز الاسترداد'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'abcd-efgh-ijkl');
      await tester.tap(find.text('تأكيد'));
      await tester.runAsync(_settle);
      await tester.pump();

      expect(find.textContaining('server words'), findsNothing);
      expect(find.text('الرمز غير صحيح. حاول مرة أخرى.'), findsOneWidget);
    });
  });
}
