import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/top_up_options.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';
import '../models/top_up_options_dto.dart';
import '../models/wallet_balance_dto.dart';
import '../models/wallet_transaction_dto.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({required WalletRemoteDataSource remote}) : _remote = remote;

  final WalletRemoteDataSource _remote;

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async {
    final result = await _remote.getBalance();
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, WalletBalanceDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _remote.getTransactions(
      type: type,
      from: from,
      to: to,
      page: page,
      pageSize: pageSize,
    );
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<WalletTransactionDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  }) async {
    final result = await _remote.requestTopUp(
      amountCents: amountCents,
      method: method,
      referenceNumber: referenceNumber,
      idempotencyKey: idempotencyKey,
      paymentAccountId: paymentAccountId,
      receiptFileId: receiptFileId,
    );
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, WalletTransactionDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, TopUpOptions>> getTopUpOptions() async {
    final result = await _remote.getTopUpOptions();
    if (result case Left(:final value)) return Left(value);
    return Right((result as Right<Failure, TopUpOptionsDto>).value.toEntity());
  }
}
