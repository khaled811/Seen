import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/statement.dart';

/// Account statement export (Figma WAL-06). Kept apart from [WalletRepository]
/// so the ledger contract stays as it was.
abstract interface class StatementRepository {
  /// Asks the server to build the statement for [from] .. [to] (inclusive days).
  Future<Either<Failure, StatementFile>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  });
}
