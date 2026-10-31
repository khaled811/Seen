import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/constants/enums.dart';
import '../entities/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

/// Submits a top-up request. Callers are expected to have already validated
/// the raw amount (see `FormValidators.positiveAmount`) — this use case
/// trusts [amountCents] and only forwards it; it doesn't own any
/// user-facing validation message strings, which stay in the presentation
/// layer where they can be localized.
class RequestTopUpUseCase {
  const RequestTopUpUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, WalletTransaction>> call({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  }) =>
      _repository.requestTopUp(
        amountCents: amountCents,
        method: method,
        referenceNumber: referenceNumber,
        idempotencyKey: idempotencyKey,
        paymentAccountId: paymentAccountId,
        receiptFileId: receiptFileId,
      );
}
