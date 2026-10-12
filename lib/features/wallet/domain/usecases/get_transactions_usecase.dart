import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../entities/wallet_transaction.dart';
import '../repositories/wallet_repository.dart';

class GetTransactionsUseCase {
  const GetTransactionsUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, List<WalletTransaction>>> call({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) =>
      _repository.getTransactions(
        type: type,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      );
}
