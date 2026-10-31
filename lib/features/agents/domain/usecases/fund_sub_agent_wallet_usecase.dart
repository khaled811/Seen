import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/agents_repository.dart';

/// Trusts [amountCents]; the caller (the transfer sheet) is expected to
/// have already validated it against the master agent's available balance
/// via `FormValidators.maxAmount` — this use case doesn't own any
/// user-facing validation message strings, which stay in the presentation
/// layer where they can be localized.
class FundSubAgentWalletUseCase {
  const FundSubAgentWalletUseCase(this._repository);

  final AgentsRepository _repository;

  Future<Either<Failure, void>> call({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) =>
      _repository.fundSubAgentWallet(
          subAgentId: subAgentId, amountCents: amountCents, idempotencyKey: idempotencyKey, note: note);
}
