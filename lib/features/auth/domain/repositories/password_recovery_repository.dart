import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// "Forgot password": the server e-mails a one-time link that opens a web page
/// (contract 3.3). The app only asks for the e-mail; choosing the new password
/// happens on that page.
abstract interface class PasswordRecoveryRepository {
  /// Always succeeds for a well-formed request (the server never says whether an
  /// account exists); `too_many_attempts` when it is asked too often.
  Future<Either<Failure, void>> requestReset({required String email});
}
