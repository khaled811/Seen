import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/account_security.dart';

/// The signed-in user's own credentials (Figma AUTH-15 / 16). Needs a session.
abstract interface class AccountSecurityRepository {
  /// The server signs the user out of the other devices on success.
  Future<Either<Failure, void>> changePassword({required String current, required String next});

  /// The current number with its middle hidden (`+967 77 ••• 0700`), as the server shows it.
  Future<Either<Failure, String>> currentPhoneMasked();

  /// Sends a code to [newPhone] (E.164) and starts the change.
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone);

  Future<Either<Failure, PhoneChangeChallenge>> resendPhoneChange(String challengeToken);

  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code});
}
