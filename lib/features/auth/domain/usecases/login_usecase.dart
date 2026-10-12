import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_attempt_result.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthAttemptResult>> call({
    required String identifier,
    required String password,
  }) => _repository.login(identifier: identifier, password: password);
}
