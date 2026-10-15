import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/password_recovery.dart';
import '../models/recovery_challenge_dto.dart';
import 'password_recovery_remote_data_source.dart';

/// DEBUG ONLY: decorates the real data source and, when a real call fails in a
/// debug build, answers with canned results so the whole recovery flow (and its
/// error states) can be tried before the backend exists. `kDebugMode` is a
/// compile-time constant, so release builds drop every fallback branch.
///
/// Demo rules: an identifier ending in `0711` is an unknown account, `0722` is
/// rate limited (4:59), anything else succeeds. The code `123456` is correct,
/// `000000` is expired, any other code is wrong (3 tries, then locked). The
/// password `Old@12345` counts as a previously used one.
class DebugFallbackPasswordRecoveryRemoteDataSource implements PasswordRecoveryRemoteDataSource {
  DebugFallbackPasswordRecoveryRemoteDataSource(this._real);

  final PasswordRecoveryRemoteDataSource _real;
  int _triesLeft = 3;

  static const _challenge = RecoveryChallengeDto(
    challengeToken: 'debug-challenge',
    maskedDestination: '+967 77 ••• 0700',
    resendCooldownSeconds: 45,
  );

  @override
  Future<Either<Failure, RecoveryChallengeDto>> requestCode({required String identifier}) async {
    final result = await _real.requestCode(identifier: identifier);
    if (!(kDebugMode && result.isLeft())) return result;
    _triesLeft = 3;
    if (identifier.endsWith('0711')) {
      return const Left(ServerFailure('Account not found', code: RecoveryIssue.accountNotFound));
    }
    if (identifier.endsWith('0722')) {
      return const Left(
        ServerFailure('Rate limited', code: RecoveryIssue.rateLimitedCode, details: {'retryAfterSeconds': 299}),
      );
    }
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, RecoveryChallengeDto>> resendCode({required String challengeToken}) async {
    final result = await _real.resendCode(challengeToken: challengeToken);
    if (!(kDebugMode && result.isLeft())) return result;
    _triesLeft = 3;
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code}) async {
    final result = await _real.verifyCode(challengeToken: challengeToken, code: code);
    if (!(kDebugMode && result.isLeft())) return result;
    if (code == '123456') return const Right('debug-reset-token');
    if (code == '000000') return const Left(ServerFailure('Expired', code: RecoveryIssue.expiredCodeCode));
    _triesLeft--;
    if (_triesLeft <= 0) {
      return const Left(
        ServerFailure('Exhausted', code: RecoveryIssue.exhaustedCode, details: {'lockoutMinutes': 15}),
      );
    }
    return Left(ServerFailure('Wrong code', code: RecoveryIssue.wrongCodeCode, details: {'attemptsLeft': _triesLeft}));
  }

  @override
  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword}) async {
    final result = await _real.resetPassword(resetToken: resetToken, newPassword: newPassword);
    if (!(kDebugMode && result.isLeft())) return result;
    if (newPassword == 'Old@12345') {
      return const Left(ServerFailure('Reused', code: RecoveryIssue.passwordReusedCode));
    }
    return const Right(null);
  }
}
