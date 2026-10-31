import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/two_factor.dart';

/// The signed-in user's own two-step verification. Needs a session.
///
/// The contract has no operation to turn it off (only an administrator's
/// `resetUser2fa`), so there is none here (DECISIONS D-34).
abstract interface class TwoFactorRepository {
  Future<Either<Failure, TwoFactorStatus>> status();

  /// Starts (or restarts an unconfirmed) enrollment; never touches a confirmed device.
  Future<Either<Failure, TwoFactorSetup>> begin();

  /// Confirms the first code; the server returns the recovery codes, once.
  Future<Either<Failure, List<String>>> confirm(String code);

  /// New recovery codes (the old ones stop working); needs a fresh authenticator code.
  Future<Either<Failure, List<String>>> regenerateRecoveryCodes(String code);
}
