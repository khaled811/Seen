import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_attempt_result.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_payload_dto.dart';
import '../models/auth_user_dto.dart';
import '../models/otp_challenge_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<Either<Failure, AuthAttemptResult>> login({
    required String identifier,
    required String password,
  }) async {
    final result =
        await _remote.login(identifier: identifier, password: password);
    if (result case Left(:final value)) return Left(value);
    return _toDomainAndPersist((result as Right<Failure, AuthPayloadDto>).value);
  }

  @override
  Future<Either<Failure, UserSession>> verifyOtp({
    required String challengeToken,
    required String code,
  }) async {
    final result =
        await _remote.verifyOtp(challengeToken: challengeToken, code: code);
    if (result case Left(:final value)) return Left(value);
    final domainResult =
        await _toDomainAndPersist((result as Right<Failure, AuthPayloadDto>).value);
    return switch (domainResult) {
      Left(:final value) => Left(value),
      Right(value: AuthSuccess(:final session)) => Right(session),
      Right(value: AuthOtpChallenge()) => const Left(
          ServerFailure('Server still requires OTP after verification.'),
        ),
    };
  }

  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({
    required String challengeToken,
  }) async {
    final result = await _remote.resendOtp(challengeToken: challengeToken);
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, OtpChallengeDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, void>> logout() async {
    await _local.clear();
    return const Right(null);
  }

  @override
  Future<UserSession?> getPersistedSession() async {
    final token = await _local.readToken();
    if (token == null) return null;
    final userDto = await _local.readUser();
    return userDto?.toEntity();
  }

  /// Maps [dto] to the domain result and, if it's a completed
  /// authentication, persists the token + user locally.
  Future<Either<Failure, AuthAttemptResult>> _toDomainAndPersist(
    AuthPayloadDto dto,
  ) async {
    try {
      final domain = dto.toDomain();
      if (domain is AuthSuccess) {
        await _local.saveSession(
          accessToken: domain.accessToken,
          user: AuthUserDto.fromEntity(domain.session),
        );
      }
      return Right(domain);
    } on FormatException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
