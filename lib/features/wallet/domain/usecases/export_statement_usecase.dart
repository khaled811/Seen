import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/statement.dart';
import '../repositories/statement_repository.dart';

class ExportStatementUseCase {
  const ExportStatementUseCase(this._repository);

  final StatementRepository _repository;

  Future<Either<Failure, StatementFile>> call({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  }) =>
      _repository.exportStatement(from: from, to: to, format: format);
}
