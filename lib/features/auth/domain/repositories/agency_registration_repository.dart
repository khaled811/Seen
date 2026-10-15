import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/agency_registration.dart';

/// Agency self-registration after the form (Figma AUTH-05 … 07). The password
/// travels once, with the request that sends the phone code.
abstract interface class AgencyRegistrationRepository {
  /// Stores the pending registration and texts a code to [draft.phone].
  Future<Either<Failure, RegistrationChallenge>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  });

  Future<Either<Failure, RegistrationChallenge>> resendCode({required String challengeToken});

  /// Returns a verification token to present with the consent.
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code});

  /// Submits the registration for review.
  Future<Either<Failure, void>> complete({required String verificationToken, required RegistrationConsent consent});
}
