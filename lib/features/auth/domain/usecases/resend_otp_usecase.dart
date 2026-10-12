import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_attempt_result.dart';
import '../repositories/auth_repository.dart';

class ResendOtpUseCase {
  const ResendOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthOtpChallenge>> call({
    required String challengeToken,
  }) => _repository.resendOtp(challengeToken: challengeToken);
}
