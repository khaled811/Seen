import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/sensitive_value.dart';

/// The sensitive values of a request's travelers: which exist (hidden) and the audited reveal
/// of one. Nothing is cached: a reveal is a fresh, logged call every time.
abstract interface class SensitiveValuesRepository {
  /// In the request's traveler order.
  Future<Either<Failure, List<TravelerSensitive>>> forRequest(String requestId);

  /// The clear text of one value. Fails with `too_many_attempts` (rate limit, minutes in the
  /// details) or `permission_denied`.
  Future<Either<Failure, String>> reveal(String valueId);
}
