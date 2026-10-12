import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/wallet_balance.dart';
import '../repositories/wallet_repository.dart';

class GetWalletBalanceUseCase {
  const GetWalletBalanceUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, WalletBalance>> call() => _repository.getBalance();
}
