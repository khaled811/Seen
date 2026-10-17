import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/wallet_transaction.dart';
import '../repositories/top_up_cancellation_repository.dart';

class CancelTopUpUseCase {
  const CancelTopUpUseCase(this._repository);

  final TopUpCancellationRepository _repository;

  Future<Either<Failure, WalletTransaction>> call(String transactionId) => _repository.cancelTopUp(transactionId);
}
