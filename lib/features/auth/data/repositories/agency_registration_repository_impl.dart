import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_registration.dart';
import '../../domain/repositories/agency_registration_repository.dart';
import '../datasources/agency_registration_remote_data_source.dart';

class AgencyRegistrationRepositoryImpl implements AgencyRegistrationRepository {
  const AgencyRegistrationRepositoryImpl({required AgencyRegistrationRemoteDataSource remote}) : _remote = remote;

  final AgencyRegistrationRemoteDataSource _remote;

  @override
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  }) =>
      _remote.register(draft: draft, password: password, consent: consent);
}
