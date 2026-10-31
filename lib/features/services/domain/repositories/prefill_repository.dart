import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/prefill.dart';

abstract interface class PrefillRepository {
  /// Earlier requests that may be copied into a new request of [serviceId]: newest
  /// first, at most 20. Empty when the service has no such rule.
  Future<Either<Failure, List<PrefillCandidate>>> candidates(String serviceId);

  /// The values of [sourceRequestId] for a new request of [serviceId]. The server
  /// audits this read (it returns the clear text, sensitive fields included).
  Future<Either<Failure, PrefillValues>> valuesFrom({required String serviceId, required String sourceRequestId});
}
