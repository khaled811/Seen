import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_registration.dart';
import '../../domain/repositories/agency_registration_repository.dart';
import '../datasources/agency_registration_remote_data_source.dart';

class AgencyRegistrationRepositoryImpl implements AgencyRegistrationRepository {
  const AgencyRegistrationRepositoryImpl({required AgencyRegistrationRemoteDataSource remote}) : _remote = remote;

  final AgencyRegistrationRemoteDataSource _remote;

  @override
  Future<Either<Failure, RegistrationChallenge>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  }) async =>
      (await _remote.start(draft: draft, password: password)).map((dto) => dto.toEntity());

  @override
  Future<Either<Failure, RegistrationChallenge>> resendCode({required String challengeToken}) async =>
      (await _remote.resendCode(challengeToken: challengeToken)).map((dto) => dto.toEntity());

  @override
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code}) =>
      _remote.verifyPhone(challengeToken: challengeToken, code: code);

  @override
  Future<Either<Failure, void>> complete({
    required String verificationToken,
    required RegistrationConsent consent,
  }) =>
      _remote.complete(verificationToken: verificationToken, consent: consent);
}
