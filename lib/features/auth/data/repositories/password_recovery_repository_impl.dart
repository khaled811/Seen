import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/repositories/password_recovery_repository.dart';
import '../datasources/password_recovery_remote_data_source.dart';

class PasswordRecoveryRepositoryImpl implements PasswordRecoveryRepository {
  const PasswordRecoveryRepositoryImpl({required PasswordRecoveryRemoteDataSource remote}) : _remote = remote;

  final PasswordRecoveryRemoteDataSource _remote;

  @override
  Future<Either<Failure, void>> requestReset({required String email}) => _remote.requestReset(email: email);
}
