import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/wallet_transaction.dart';

/// Withdrawing a pending top-up request (Figma WAL-02). Kept apart from
/// [WalletRepository] so the ledger contract stays as it was.
abstract interface class TopUpCancellationRepository {
  /// Returns the updated transaction. A request finance already decided fails
  /// with `ServerFailure.code == 'NOT_CANCELLABLE'`.
  Future<Either<Failure, WalletTransaction>> cancelTopUp(String transactionId);
}
