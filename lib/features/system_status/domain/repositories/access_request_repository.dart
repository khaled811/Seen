import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// Asks the account owner for a permission the signed-in user lacks (Figma
/// SYS-03). [area] names what was refused, e.g. `wallet`.
abstract interface class AccessRequestRepository {
  Future<Either<Failure, void>> request(String area);
}
