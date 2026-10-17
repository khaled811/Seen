import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/statement.dart';
import '../../domain/repositories/statement_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class StatementRepositoryImpl implements StatementRepository {
  StatementRepositoryImpl({required WalletRemoteDataSource remote}) : _remote = remote;

  final WalletRemoteDataSource _remote;

  @override
  Future<Either<Failure, StatementFile>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  }) async {
    final result = await _remote.exportStatement(from: from, to: to, format: format);
    return result.map((dto) => dto.toEntity());
  }
}
