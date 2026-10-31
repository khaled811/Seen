import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_registration.dart';
import '../repositories/agency_registration_repository.dart';

class RegisterAgencyUseCase {
  const RegisterAgencyUseCase(this._repository);
  final AgencyRegistrationRepository _repository;

  Future<Either<Failure, void>> call({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  }) =>
      _repository.register(draft: draft, password: password, consent: consent);
}
