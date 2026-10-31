import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_registration.dart';

/// Agency self-registration (Figma AUTH-05 / AUTH-07). One call, `registerMainAgent`,
/// creates a pending agency and e-mails the owner a confirmation link; Seen then
/// approves it (contract 3.2). There is no phone code.
abstract interface class AgencyRegistrationRepository {
  /// The password travels once, with this request, and is never kept.
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  });
}
