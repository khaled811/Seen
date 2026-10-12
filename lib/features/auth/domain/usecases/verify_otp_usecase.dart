import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_session.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserSession>> call({
    required String challengeToken,
    required String code,
  }) => _repository.verifyOtp(challengeToken: challengeToken, code: code);
}
