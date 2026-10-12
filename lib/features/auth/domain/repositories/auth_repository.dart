import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_attempt_result.dart';
import '../entities/user_session.dart';

/// Contract for the auth feature's data. Implemented in the data layer;
/// depended on (never implemented) by use cases in the domain layer.
abstract interface class AuthRepository {
  /// Submits credentials. Returns either an [AuthOtpChallenge] (verify next)
  /// or an [AuthSuccess] (already authenticated) — see [AuthAttemptResult].
  Future<Either<Failure, AuthAttemptResult>> login({
    required String identifier,
    required String password,
  });

  /// Completes an OTP challenge, returning the authenticated session.
  Future<Either<Failure, UserSession>> verifyOtp({
    required String challengeToken,
    required String code,
  });

  /// Requests a new OTP code for an existing challenge.
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({
    required String challengeToken,
  });

  /// Clears the locally persisted session.
  Future<Either<Failure, void>> logout();

  /// Reads whatever session was persisted locally, or `null` if there is
  /// none (including when the local cache is missing or unreadable — a
  /// failed read is treated the same as "no session", never as an error the
  /// caller must handle).
  Future<UserSession?> getPersistedSession();
}
