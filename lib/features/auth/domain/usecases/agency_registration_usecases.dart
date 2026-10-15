import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_registration.dart';
import '../repositories/agency_registration_repository.dart';

class StartAgencyRegistrationUseCase {
  const StartAgencyRegistrationUseCase(this._repository);
  final AgencyRegistrationRepository _repository;

  Future<Either<Failure, RegistrationChallenge>> call({
    required AgencyRegistrationDraft draft,
    required String password,
  }) =>
      _repository.start(draft: draft, password: password);
}

class ResendRegistrationCodeUseCase {
  const ResendRegistrationCodeUseCase(this._repository);
  final AgencyRegistrationRepository _repository;

  Future<Either<Failure, RegistrationChallenge>> call({required String challengeToken}) =>
      _repository.resendCode(challengeToken: challengeToken);
}

class VerifyRegistrationPhoneUseCase {
  const VerifyRegistrationPhoneUseCase(this._repository);
  final AgencyRegistrationRepository _repository;

  Future<Either<Failure, String>> call({required String challengeToken, required String code}) =>
      _repository.verifyPhone(challengeToken: challengeToken, code: code);
}

class CompleteAgencyRegistrationUseCase {
  const CompleteAgencyRegistrationUseCase(this._repository);
  final AgencyRegistrationRepository _repository;

  Future<Either<Failure, void>> call({required String verificationToken, required RegistrationConsent consent}) =>
      _repository.complete(verificationToken: verificationToken, consent: consent);
}
