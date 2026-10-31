import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_top_up.dart';
import 'package:seen_booking/features/agents/domain/repositories/sub_agent_top_up_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/sub_agent_top_up_usecases.dart';
import 'package:seen_booking/features/agents/presentation/bloc/sub_agent_top_ups_cubit.dart';

/// A funding-requests repository driven by the test.
class FakeSubAgentTopUpRepository implements SubAgentTopUpRepository {
  FakeSubAgentTopUpRepository([List<SubAgentTopUp> items = const []]) : items = List.of(items);

  List<SubAgentTopUp> items;
  Failure? pendingFailure;
  Failure? decisionFailure;
  final approved = <String>[];
  final rejected = <({String id, String note})>[];
  int pendingCalls = 0;

  @override
  Future<Either<Failure, List<SubAgentTopUp>>> pending() async {
    pendingCalls++;
    return pendingFailure != null ? Left(pendingFailure!) : Right(List.of(items));
  }

  @override
  Future<Either<Failure, void>> approve(String transactionId) async {
    approved.add(transactionId);
    if (decisionFailure != null) return Left(decisionFailure!);
    items.removeWhere((t) => t.id == transactionId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> reject(String transactionId, {required String note}) async {
    rejected.add((id: transactionId, note: note));
    if (decisionFailure != null) return Left(decisionFailure!);
    items.removeWhere((t) => t.id == transactionId);
    return const Right(null);
  }
}

/// A cubit with no funding requests: the approvals screen shows only the requests.
SubAgentTopUpsCubit emptyTopUpsCubit() => SubAgentTopUpsCubit(SubAgentTopUpUseCases(FakeSubAgentTopUpRepository()));
