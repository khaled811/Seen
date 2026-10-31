import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract interface class SubAgentReclaimRepository {
  /// Takes [amountCents] back from a sub-agency's wallet into the main agent's
  /// (`reclaimFromSubAgent`). [idempotencyKey] makes a retry of the same action safe:
  /// the server never moves the money twice for one key.
  Future<Either<Failure, void>> reclaim({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  });
}
