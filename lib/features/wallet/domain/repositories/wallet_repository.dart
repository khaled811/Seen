import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../entities/top_up_options.dart';
import '../entities/wallet_balance.dart';
import '../entities/wallet_transaction.dart';

abstract interface class WalletRepository {
  Future<Either<Failure, WalletBalance>> getBalance();

  /// [type]/[from]/[to] are optional server-side filters; a `null` filter is
  /// "no constraint". [page]/[pageSize] exist so the ledger stays workable
  /// as history grows — the current UI only requests page 1, but the
  /// contract is here for when it needs more.
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  /// Submits a top-up request. Returns the created (pending) transaction.
  ///
  /// Receipt upload is intentionally not a parameter here yet — per Task 06,
  /// that step is mocked/decoupled until the backend's Supabase mutations
  /// are active.
  /// Files a top-up request (pending until Seen approves it). [idempotencyKey]
  /// is one UUID per user action, reused when that same action is retried.
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  });

  /// The methods, the accounts to pay into and the minimum amount.
  Future<Either<Failure, TopUpOptions>> getTopUpOptions();
}
