import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/config/debug_fallbacks.dart';
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
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<UserSession?> getPersistedSession() async => null;
}

AuthBloc _bloc() {
  final repo = _Repo();
  return AuthBloc(
    loginUseCase: LoginUseCase(repo),
    verifyOtpUseCase: VerifyOtpUseCase(repo),
    resendOtpUseCase: ResendOtpUseCase(repo),
    logoutUseCase: LogoutUseCase(repo),
    getPersistedSessionUseCase: GetPersistedSessionUseCase(repo),
    authSessionController: AuthSessionController(),
  );
}

void main() {
  final saved = DebugFallbacks.testOverride;
  tearDown(() => DebugFallbacks.testOverride = saved);

  test('the debug auth bypass does nothing unless debug fallbacks are opted in', () async {
    DebugFallbacks.testOverride = false;
    final bloc = _bloc();
    addTearDown(bloc.close);

    bloc.add(const AuthDebugBypassRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isNot(isA<AuthAuthenticated>()));
  });

  test('with the opt-in it still signs the fake debug session in', () async {
    DebugFallbacks.testOverride = true;
    final bloc = _bloc();
    addTearDown(bloc.close);

    bloc.add(const AuthDebugBypassRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthAuthenticated>());
  });
}
