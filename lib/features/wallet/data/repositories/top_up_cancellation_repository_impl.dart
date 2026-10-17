import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/top_up_cancellation_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class TopUpCancellationRepositoryImpl implements TopUpCancellationRepository {
  TopUpCancellationRepositoryImpl({required WalletRemoteDataSource remote}) : _remote = remote;

  final WalletRemoteDataSource _remote;

  @override
  Future<Either<Failure, WalletTransaction>> cancelTopUp(String transactionId) async {
    final result = await _remote.cancelTopUp(transactionId);
    return result.map((dto) => dto.toEntity());
  }
}
