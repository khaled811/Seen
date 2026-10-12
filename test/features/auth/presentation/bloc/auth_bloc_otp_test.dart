// AuthBloc OTP flow: the identifier travels with AuthOtpRequired (display only)
// and AuthOtpCancelled returns to Login without any network call.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
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

class _FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<Either<Failure, AuthAttemptResult>> login({required String identifier, required String password}) async =>
      const Right(AuthOtpChallenge(challengeToken: 'tok', resendCooldownSeconds: 30));

  @override
  Future<Either<Failure, UserSession>> verifyOtp({required String challengeToken, required String code}) async =>
      const Left(ServerFailure('bad code'));

  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({required String challengeToken}) async =>
      const Right(AuthOtpChallenge(challengeToken: 'tok2', resendCooldownSeconds: 45));

  @override
  Future<Either<Failure, void>> logout() async {
    logoutCalls++;
    return const Right(null);
  }

  @override
  Future<UserSession?> getPersistedSession() async => null;
}

AuthBloc _bloc(_FakeAuthRepository repo) => AuthBloc(
      loginUseCase: LoginUseCase(repo),
      verifyOtpUseCase: VerifyOtpUseCase(repo),
      resendOtpUseCase: ResendOtpUseCase(repo),
      logoutUseCase: LogoutUseCase(repo),
      getPersistedSessionUseCase: GetPersistedSessionUseCase(repo),
      authSessionController: AuthSessionController(),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('login that needs OTP carries the identifier into AuthOtpRequired, also after a resend', () async {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);

    bloc.add(const AuthLoginSubmitted(identifier: '+967771234567', password: 'pw'));
    await _settle();
    expect(bloc.state, const AuthOtpRequired(challengeToken: 'tok', resendCooldownSeconds: 30, identifier: '+967771234567'));

    bloc.add(const AuthOtpResendRequested());
    await _settle();
    expect(bloc.state, const AuthOtpRequired(challengeToken: 'tok2', resendCooldownSeconds: 45, identifier: '+967771234567'));
  });

  test('AuthOtpCancelled returns to Login without calling logout', () async {
    final repo = _FakeAuthRepository();
    final bloc = _bloc(repo);
    addTearDown(bloc.close);

    bloc.add(const AuthLoginSubmitted(identifier: 'a@b.co', password: 'pw'));
    await _settle();
    bloc.add(const AuthOtpCancelled());
    await _settle();

    expect(bloc.state, const AuthUnauthenticated(startOnLogin: true));
    expect(repo.logoutCalls, 0);
  });

  test('AuthOtpCancelled also works after a failed code', () async {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);

    bloc.add(const AuthLoginSubmitted(identifier: 'a@b.co', password: 'pw'));
    await _settle();
    bloc.add(const AuthOtpSubmitted(code: '123456'));
    await _settle();
    expect(bloc.state, isA<AuthFailure>());

    bloc.add(const AuthOtpCancelled());
    await _settle();
    expect(bloc.state, const AuthUnauthenticated(startOnLogin: true));
  });

  test('a stray AuthOtpCancelled with no pending challenge is ignored', () async {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);
    bloc.add(const AuthOtpCancelled());
    await _settle();
    expect(bloc.state, const AuthInitial());
  });
}
