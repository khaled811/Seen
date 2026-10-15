import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/password_recovery.dart';
import '../repositories/password_recovery_repository.dart';

class RequestPasswordResetCodeUseCase {
  const RequestPasswordResetCodeUseCase(this._repository);
  final PasswordRecoveryRepository _repository;

  Future<Either<Failure, RecoveryChallenge>> call({required String identifier}) =>
      _repository.requestCode(identifier: identifier);
}

class ResendPasswordResetCodeUseCase {
  const ResendPasswordResetCodeUseCase(this._repository);
  final PasswordRecoveryRepository _repository;

  Future<Either<Failure, RecoveryChallenge>> call({required String challengeToken}) =>
      _repository.resendCode(challengeToken: challengeToken);
}

class VerifyPasswordResetCodeUseCase {
  const VerifyPasswordResetCodeUseCase(this._repository);
  final PasswordRecoveryRepository _repository;

  Future<Either<Failure, String>> call({required String challengeToken, required String code}) =>
      _repository.verifyCode(challengeToken: challengeToken, code: code);
}

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);
  final PasswordRecoveryRepository _repository;

  Future<Either<Failure, void>> call({required String resetToken, required String newPassword}) =>
      _repository.resetPassword(resetToken: resetToken, newPassword: newPassword);
}
