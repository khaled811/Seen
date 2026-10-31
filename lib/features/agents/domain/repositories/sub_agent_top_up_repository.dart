import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/sub_agent_top_up.dart';

abstract interface class SubAgentTopUpRepository {
  /// The funding requests of the main agent's sub-agencies that wait for it.
  Future<Either<Failure, List<SubAgentTopUp>>> pending();

  /// Approves the request: the amount moves from the main agent's own wallet. There is no
  /// idempotency key, but the server refuses a request that was already decided.
  Future<Either<Failure, void>> approve(String transactionId);

  Future<Either<Failure, void>> reject(String transactionId, {required String note});
}
