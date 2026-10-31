import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/sub_agent_reclaim_repository.dart';

/// Trusts [amountCents]; the sheet checks it against the sub-agency's balance, and the
/// server checks it again.
class ReclaimFromSubAgentUseCase {
  const ReclaimFromSubAgentUseCase(this._repository);

  final SubAgentReclaimRepository _repository;

  Future<Either<Failure, void>> call({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) =>
      _repository.reclaim(subAgentId: subAgentId, amountCents: amountCents, idempotencyKey: idempotencyKey, note: note);
}
