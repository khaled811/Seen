import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/refresh_coordinator.dart';
import '../../../../core/network/session_manager.dart';
import '../../domain/entities/auth_attempt_result.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_payload_dto.dart';
import '../models/me_dto.dart';

/// Sign-in, the second step, restoring a session and signing out, against the
/// real contract (`docs/api/mobile-api.md` section 3).
///
/// Nothing is persisted here: the access token lives in memory (through
/// [SessionManager]) and the refresh cookie lives in the encrypted cookie jar.
/// A session exists only after the server has said who the person is (`me`).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthRemoteDataSource remote, required SessionManager session})
      : _remote = remote,
        _session = session;

  final AuthRemoteDataSource _remote;
  final SessionManager _session;

  /// Failure codes of this repository that are not server codes.
  static const String emailRequiredCode = 'email_required';
  static const String enrollmentLinkRequiredCode = 'enrollment_link_required';
  static const String resendUnsupportedCode = 'resend_unsupported';

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  Future<Either<Failure, AuthAttemptResult>> login({required String identifier, required String password}) async {
    final email = identifier.trim();
    // The API signs in with an e-mail address only. A phone number cannot be
    // sent (and nothing is invented to turn it into one).
    if (!_email.hasMatch(email)) {
      return const Left(
        ValidationFailure('Sign-in needs the e-mail address of the account.', fieldErrors: {
          'email': [emailRequiredCode],
        }),
      );
    }
    final result = await _remote.login(email: email, password: password);
    return switch (result) {
      Left(:final value) => Left(value),
      Right(:final value) => _afterAuthPayload(value),
    };
  }

  @override
  Future<Either<Failure, UserSession>> verifyOtp({required String challengeToken, required String code}) async {
    final result = await _remote.verifyOtp(challengeId: challengeToken, code: code.trim());
    final next = switch (result) {
      Left(:final value) => Left<Failure, AuthAttemptResult>(value),
      Right(:final value) => await _afterAuthPayload(value),
    };
    return switch (next) {
      Left(:final value) => Left(value),
      Right(value: AuthSuccess(:final session)) => Right(session),
      Right(value: AuthOtpChallenge()) => const Left(ServerFailure('The server asked for a code again.')),
    };
  }

  /// The API has no operation that sends a code again: the code comes from the
  /// person's authenticator app (or a recovery code).
  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({required String challengeToken}) async =>
      const Left(ServerFailure('A code cannot be sent again.', code: resendUnsupportedCode));

  @override
  Future<Either<Failure, void>> logout() async {
    // Never throws: every step runs even when the network call fails.
    await _session.endSession();
    return const Right(null);
  }

  /// Launch-time restore: `refresh` (the cookie becomes an access token), then
  /// `me`. A session is returned only after the server confirmed it. A failed
  /// or ambiguous refresh leaves the cookie alone and signs nobody in.
  @override
  Future<UserSession?> getPersistedSession() async {
    final status = await _session.restoreAccessToken();
    if (status != RefreshStatus.refreshed) return null;
    final session = await _loadSession();
    if (session == null) {
      // Signed in as far as the transport goes, but not usable: forget the
      // token (the rotated cookie stays for the next launch).
      _session.tokens.clear();
    }
    return session;
  }

  Future<Either<Failure, AuthAttemptResult>> _afterAuthPayload(AuthPayloadDto dto) async {
    if (dto.otpRequired) {
      final id = dto.challengeId;
      if (id == null || id.isEmpty) return const Left(ServerFailure('Unexpected sign-in response.'));
      return Right(AuthOtpChallenge(challengeToken: id, resendCooldownSeconds: 0, canResend: false));
    }
    if (dto.needsEnrollment) {
      // Enrollment arrives through an e-mailed link that opens a web page; the
      // app has no way to continue it.
      return const Left(
        ServerFailure('Two-step verification must be set up with the e-mailed link.', code: enrollmentLinkRequiredCode),
      );
    }
    final token = dto.accessToken;
    if (token == null || token.isEmpty) return const Left(ServerFailure('Unexpected sign-in response.'));

    _session.startSession(token);
    final me = await _remote.me();
    switch (me) {
      case Left(:final value):
        await _session.endSession();
        return Left(value);
      case Right(:final value):
        final session = _sessionFrom(value);
        if (session == null) {
          await _session.endSession();
          return const Left(ServerFailure('This app is for agency users.', code: 'agent_side_only'));
        }
        return Right(AuthSuccess(accessToken: token, session: session));
    }
  }

  Future<UserSession?> _loadSession() async {
    final me = await _remote.me();
    return switch (me) {
      Left() => null,
      Right(:final value) => _sessionFrom(value),
    };
  }

  UserSession? _sessionFrom(MeDto me) => me.hasAgency ? me.toSession() : null;
}
