import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/password_recovery_repository.dart';

class RequestPasswordResetUseCase {
  const RequestPasswordResetUseCase(this._repository);
  final PasswordRecoveryRepository _repository;

  Future<Either<Failure, void>> call({required String email}) => _repository.requestReset(email: email);
}
