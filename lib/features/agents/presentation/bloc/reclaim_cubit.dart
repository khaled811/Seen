import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../domain/usecases/reclaim_from_sub_agent_usecase.dart';

enum ReclaimStatus { idle, submitting, done, failed }

class ReclaimState extends Equatable {
  const ReclaimState({this.status = ReclaimStatus.idle, this.failure});

  final ReclaimStatus status;
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}

/// Takes money back from one sub-agency. One key per action, kept only while the answer is
/// unknown (a dropped connection) so a retry of the same action cannot move the money twice;
/// a second tap while it runs is ignored. Owner: the sheet that shows it.
class ReclaimCubit extends Cubit<ReclaimState> {
  ReclaimCubit(this._reclaim, {required this.subAgentId, IdempotencyKeyRegistry? keys})
      : _keys = keys ?? IdempotencyKeyRegistry(),
        super(const ReclaimState());

  final ReclaimFromSubAgentUseCase _reclaim;
  final String subAgentId;
  final IdempotencyKeyRegistry _keys;

  Future<void> submit({required int amountCents, String? note}) async {
    if (state.status == ReclaimStatus.submitting || state.status == ReclaimStatus.done) return;
    emit(const ReclaimState(status: ReclaimStatus.submitting));
    final key = _keys.keyFor('$subAgentId|$amountCents|${note ?? ''}');
    final result = await _reclaim(subAgentId: subAgentId, amountCents: amountCents, idempotencyKey: key, note: note);
    if (isClosed) return;
    result.fold(
      (f) {
        // After a dropped connection the money may or may not have moved: the next try keeps the key.
        if (f is! NetworkFailure) _keys.settled();
        emit(ReclaimState(status: ReclaimStatus.failed, failure: f));
      },
      (_) {
        _keys.settled();
        emit(const ReclaimState(status: ReclaimStatus.done));
      },
    );
  }
}
