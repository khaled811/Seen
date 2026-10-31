// Sign-in, the second step, restore and sign-out against the real contract,
// with a fake remote and the real session classes.

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/access_token_store.dart';
import 'package:seen_booking/core/network/refresh_coordinator.dart';
import 'package:seen_booking/core/network/session_manager.dart';
import 'package:seen_booking/core/network/session_remote_data_source.dart';
import 'package:seen_booking/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:seen_booking/features/auth/data/models/auth_payload_dto.dart';
import 'package:seen_booking/features/auth/data/models/me_dto.dart';
import 'package:seen_booking/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:seen_booking/features/auth/domain/entities/auth_attempt_result.dart';

class _Remote implements AuthRemoteDataSource {
  Either<Failure, AuthPayloadDto> loginAnswer = const Right(AuthPayloadDto(accessToken: 'token-1'));
  Either<Failure, AuthPayloadDto> otpAnswer = const Right(AuthPayloadDto(accessToken: 'token-2'));
  Either<Failure, MeDto> meAnswer = Right(_me());
  final loginCalls = <(String, String)>[];
  final otpCalls = <(String, String)>[];
  int meCalls = 0;

  @override
  Future<Either<Failure, AuthPayloadDto>> login({required String email, required String password}) async {
    loginCalls.add((email, password));
    return loginAnswer;
  }

  @override
  Future<Either<Failure, AuthPayloadDto>> verifyOtp({required String challengeId, required String code}) async {
    otpCalls.add((challengeId, code));
    return otpAnswer;
  }

  @override
  Future<Either<Failure, MeDto>> me() async {
    meCalls++;
    return meAnswer;
  }
}

MeDto _me({bool agency = true, String position = 'owner', Set<String> permissions = const {'request.submit'}}) => MeDto(
      id: 'u1',
      agentPosition: position,
      permissions: permissions,
      hasAgency: agency,
    );

class _SessionRemote implements SessionRemoteDataSource {
  RefreshResponse refreshAnswer = const RefreshSucceeded('restored');
  int refreshes = 0;
  int logouts = 0;

  @override
  Future<RefreshResponse> refresh() async {
    refreshes++;
    return refreshAnswer;
  }

  @override
  Future<void> logout() async => logouts++;
}

class _Rig {
  _Rig() {
    manager = SessionManager(
      tokens: tokens,
      coordinator: RefreshCoordinator(tokens: tokens, remote: session),
      remote: session,
      cookieJar: DefaultCookieJar(),
      clearHttpCache: () async {},
    );
    repo = AuthRepositoryImpl(remote: remote, session: manager);
  }

  final remote = _Remote();
  final session = _SessionRemote();
  final tokens = AccessTokenStore();
  late final SessionManager manager;
  late final AuthRepositoryImpl repo;
}

void main() {
  group('login', () {
    test('signs in with an e-mail, then asks the server who it is (me) before the session exists', () async {
      final rig = _Rig();

      final result = await rig.repo.login(identifier: '  owner@agency.test ', password: 'pw');

      final success = (result as Right<Failure, AuthAttemptResult>).value as AuthSuccess;
      expect(rig.remote.loginCalls, [('owner@agency.test', 'pw')]);
      expect(rig.remote.meCalls, 1);
      expect(rig.tokens.token, 'token-1');
      expect(success.session.userId, 'u1');
      expect(success.session.userType, UserType.agent);
      expect(success.session.agentPosition, AgentPosition.owner);
      expect(success.session.permissionCodes, {'request.submit'});
    });

    test('a phone number is refused locally and never sent', () async {
      final rig = _Rig();

      final result = await rig.repo.login(identifier: '+967 771 234 567', password: 'pw');

      final failure = (result as Left<Failure, AuthAttemptResult>).value as ValidationFailure;
      expect(failure.fieldErrors['email'], [AuthRepositoryImpl.emailRequiredCode]);
      expect(rig.remote.loginCalls, isEmpty);
    });

    test('an account with two-step verification gets a challenge that cannot be resent, and no token', () async {
      final rig = _Rig();
      rig.remote.loginAnswer = const Right(AuthPayloadDto(otpRequired: true, challengeId: 'ch-9'));

      final result = await rig.repo.login(identifier: 'a@b.test', password: 'pw');

      final challenge = (result as Right<Failure, AuthAttemptResult>).value as AuthOtpChallenge;
      expect(challenge.challengeToken, 'ch-9');
      expect(challenge.canResend, isFalse);
      expect(rig.tokens.hasToken, isFalse);
      expect(rig.remote.meCalls, 0);
    });

    test('enrollment cannot continue in the app: a clear failure, no token', () async {
      final rig = _Rig();
      rig.remote.loginAnswer = const Right(AuthPayloadDto(enrollmentRequired: true));

      final result = await rig.repo.login(identifier: 'a@b.test', password: 'pw');

      expect(((result as Left<Failure, AuthAttemptResult>).value as ServerFailure).code,
          AuthRepositoryImpl.enrollmentLinkRequiredCode);
      expect(rig.tokens.hasToken, isFalse);
    });

    test('a server failure is passed through untouched', () async {
      final rig = _Rig();
      rig.remote.loginAnswer = const Left(ServerFailure('x', code: 'invalid_credentials'));

      final result = await rig.repo.login(identifier: 'a@b.test', password: 'pw');

      expect(((result as Left<Failure, AuthAttemptResult>).value as ServerFailure).code, 'invalid_credentials');
      expect(rig.tokens.hasToken, isFalse);
    });

    test('if me fails after the token arrived, the half-open session is ended', () async {
      final rig = _Rig();
      rig.remote.meAnswer = const Left(NetworkFailure('offline'));

      final result = await rig.repo.login(identifier: 'a@b.test', password: 'pw');

      expect(result.isLeft(), isTrue);
      expect(rig.tokens.hasToken, isFalse);
      expect(rig.session.logouts, 1);
    });

    test('a Seen-staff account (no agency) is refused and its session ended', () async {
      final rig = _Rig();
      rig.remote.meAnswer = Right(_me(agency: false));

      final result = await rig.repo.login(identifier: 'staff@seen.test', password: 'pw');

      expect(((result as Left<Failure, AuthAttemptResult>).value as ServerFailure).code, 'agent_side_only');
      expect(rig.tokens.hasToken, isFalse);
      expect(rig.session.logouts, 1);
    });

    test('an unknown position or no permissions yields a session that can do nothing', () async {
      final rig = _Rig();
      rig.remote.meAnswer = Right(_me(position: 'galactic_admin', permissions: const {}));

      final result = await rig.repo.login(identifier: 'a@b.test', password: 'pw');

      final session = ((result as Right<Failure, AuthAttemptResult>).value as AuthSuccess).session;
      expect(session.agentPosition, AgentPosition.unknown);
      expect(session.permissionCodes, isEmpty);
      expect(session.hasPermission('request.submit'), isFalse);
    });
  });

  group('verifyOtp', () {
    test('sends the challenge id and the trimmed code (authenticator or recovery code) and returns the session', () async {
      final rig = _Rig();

      final result = await rig.repo.verifyOtp(challengeToken: 'ch-9', code: ' abcd-efgh-ijkl ');

      expect(rig.remote.otpCalls, [('ch-9', 'abcd-efgh-ijkl')]);
      expect(result.isRight(), isTrue);
      expect(rig.tokens.token, 'token-2');
    });

    test('a wrong code is passed through', () async {
      final rig = _Rig();
      rig.remote.otpAnswer = const Left(ServerFailure('x', code: 'otp_code_invalid'));

      final result = await rig.repo.verifyOtp(challengeToken: 'ch-9', code: '000000');

      expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, 'otp_code_invalid');
      expect(rig.tokens.hasToken, isFalse);
    });

    test('the server asking for a code again is a failure, not a loop', () async {
      final rig = _Rig();
      rig.remote.otpAnswer = const Right(AuthPayloadDto(otpRequired: true, challengeId: 'again'));

      expect((await rig.repo.verifyOtp(challengeToken: 'ch-9', code: '123456')).isLeft(), isTrue);
    });
  });

  test('a code cannot be sent again: there is no such operation', () async {
    final result = await _Rig().repo.resendOtp(challengeToken: 'ch-9');

    expect(((result as Left<Failure, AuthOtpChallenge>).value as ServerFailure).code,
        AuthRepositoryImpl.resendUnsupportedCode);
  });

  group('restoring a session at launch', () {
    test('refresh, then me, then the session', () async {
      final rig = _Rig();

      final session = await rig.repo.getPersistedSession();

      expect(session?.userId, 'u1');
      expect(rig.session.refreshes, 1);
      expect(rig.remote.meCalls, 1);
      expect(rig.tokens.token, 'restored');
    });

    test('no cookie or an ended session means signed out, without calling me', () async {
      final rig = _Rig();
      rig.session.refreshAnswer = const RefreshRejected('no_refresh_session');

      expect(await rig.repo.getPersistedSession(), isNull);
      expect(rig.remote.meCalls, 0);
    });

    test('an unreachable server signs nobody in and leaves the credentials alone', () async {
      final rig = _Rig();
      rig.session.refreshAnswer = const RefreshUnavailable();

      expect(await rig.repo.getPersistedSession(), isNull);
      expect(rig.remote.meCalls, 0);
      expect(rig.session.logouts, 0);
    });

    test('a token without a confirmed identity is dropped', () async {
      final rig = _Rig();
      rig.remote.meAnswer = const Left(NetworkFailure('offline'));

      expect(await rig.repo.getPersistedSession(), isNull);
      expect(rig.tokens.hasToken, isFalse);
    });
  });

  test('logout asks the server and clears the in-memory token', () async {
    final rig = _Rig();
    await rig.repo.login(identifier: 'a@b.test', password: 'pw');

    final result = await rig.repo.logout();

    expect(result.isRight(), isTrue);
    expect(rig.session.logouts, 1);
    expect(rig.tokens.hasToken, isFalse);
  });
}
