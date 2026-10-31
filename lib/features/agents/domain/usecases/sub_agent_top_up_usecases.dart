import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/sub_agent_top_up.dart';
import '../repositories/sub_agent_top_up_repository.dart';

/// The sub-agent funding requests screen's operations, grouped (one repository, one cubit).
class SubAgentTopUpUseCases {
  const SubAgentTopUpUseCases(this._repository);

  final SubAgentTopUpRepository _repository;

  Future<Either<Failure, List<SubAgentTopUp>>> pending() => _repository.pending();

  Future<Either<Failure, void>> approve(String transactionId) => _repository.approve(transactionId);

  Future<Either<Failure, void>> reject(String transactionId, {required String note}) =>
      _repository.reject(transactionId, note: note);
}
