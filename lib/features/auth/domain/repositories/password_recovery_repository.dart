import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/password_recovery.dart';

/// "Forgot password": ask for a code, verify it, set a new password. Failures
/// carry backend codes that [RecoveryIssue.from] understands.
abstract interface class PasswordRecoveryRepository {
  Future<Either<Failure, RecoveryChallenge>> requestCode({required String identifier});

  Future<Either<Failure, RecoveryChallenge>> resendCode({required String challengeToken});

  /// Returns the one-time reset token that [resetPassword] needs.
  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code});

  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword});
}
