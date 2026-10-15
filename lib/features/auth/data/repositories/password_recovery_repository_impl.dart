import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/password_recovery.dart';
import '../../domain/repositories/password_recovery_repository.dart';
import '../datasources/password_recovery_remote_data_source.dart';

class PasswordRecoveryRepositoryImpl implements PasswordRecoveryRepository {
  const PasswordRecoveryRepositoryImpl({required PasswordRecoveryRemoteDataSource remote}) : _remote = remote;

  final PasswordRecoveryRemoteDataSource _remote;

  @override
  Future<Either<Failure, RecoveryChallenge>> requestCode({required String identifier}) async =>
      (await _remote.requestCode(identifier: identifier)).map((dto) => dto.toEntity());

  @override
  Future<Either<Failure, RecoveryChallenge>> resendCode({required String challengeToken}) async =>
      (await _remote.resendCode(challengeToken: challengeToken)).map((dto) => dto.toEntity());

  @override
  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code}) =>
      _remote.verifyCode(challengeToken: challengeToken, code: code);

  @override
  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword}) =>
      _remote.resetPassword(resetToken: resetToken, newPassword: newPassword);
}
