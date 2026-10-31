import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/top_up_options.dart';
import '../repositories/wallet_repository.dart';

class GetTopUpOptionsUseCase {
  const GetTopUpOptionsUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, TopUpOptions>> call() => _repository.getTopUpOptions();
}
