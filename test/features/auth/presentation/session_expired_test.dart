// Session expired (Figma AUTH-13): the bloc keeps the session under a dialog
// until it is acknowledged, then clears it and shows Login; the app gate shows
// the blocking dialog over the current screen.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/app.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
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

class _Repo implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<Either<Failure, AuthAttemptResult>> login({required String identifier, required String password}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, UserSession>> verifyOtp({required String challengeToken, required String code}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({required String challengeToken}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, void>> logout() async {
    logoutCalls++;
    return const Right(null);
  }

  @override
  Future<UserSession?> getPersistedSession() async => null;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthBloc session expiry', () {
    late _Repo repo;
    late AuthSessionController controller;
    late AuthBloc bloc;

    setUp(() {
      repo = _Repo();
      controller = AuthSessionController();
      bloc = AuthBloc(
        loginUseCase: LoginUseCase(repo),
        verifyOtpUseCase: VerifyOtpUseCase(repo),
        resendOtpUseCase: ResendOtpUseCase(repo),
        logoutUseCase: LogoutUseCase(repo),
        getPersistedSessionUseCase: GetPersistedSessionUseCase(repo),
        authSessionController: controller,
      );
    });

    tearDown(() => bloc.close());

    test('a 401 while signed in keeps the session under AuthSessionExpired, once', () async {
      bloc.add(const AuthDebugBypassRequested());
      await _settle();
      final session = (bloc.state as AuthAuthenticated).session;

      controller
        ..notifyUnauthenticated()
        ..notifyUnauthenticated();
      await _settle();
      expect(bloc.state, AuthSessionExpired(session));
      expect(repo.logoutCalls, 0);
    });

    test('acknowledging clears the stored session and opens Login', () async {
      bloc.add(const AuthDebugBypassRequested());
      await _settle();
      controller.notifyUnauthenticated();
      await _settle();

      bloc.add(const AuthSessionExpiredAcknowledged());
      await _settle();
      expect(bloc.state, const AuthUnauthenticated(startOnLogin: true));
      expect(repo.logoutCalls, 1);
    });

    test('a 401 while signed out behaves as before (no dialog state)', () async {
      bloc.add(const AuthCheckRequested());
      await _settle();
      controller.notifyUnauthenticated();
      await _settle();
      expect(bloc.state, const AuthUnauthenticated());
    });

    test('a stray acknowledgement without an expired session is ignored', () async {
      bloc.add(const AuthSessionExpiredAcknowledged());
      await _settle();
      expect(repo.logoutCalls, 0);
    });
  });

  testWidgets('the gate shows the blocking dialog over the app and Sign in goes to Login', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App(splashMinDuration: Duration.zero));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل الدخول').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Bypass Auth'));
    await tester.tap(find.textContaining('Bypass Auth'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انتهت الجلسة'), findsNothing);

    InjectionContainer.instance.authSessionController.notifyUnauthenticated();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انتهت الجلسة'), findsOneWidget);

    // Neither the system back gesture nor the scrim dismisses it.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انتهت الجلسة'), findsOneWidget);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انتهت الجلسة'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Bypass Auth'), findsOneWidget); // Login again
  });
}
