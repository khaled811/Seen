import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/remind_approver_usecase.dart';

enum ReminderStatus { idle, sending, sent, tooSoon, failed }

class ReminderState extends Equatable {
  const ReminderState({this.status = ReminderStatus.idle, this.retryAfterSeconds, this.seq = 0});

  final ReminderStatus status;

  /// `tooSoon`: when the approver may be reminded again.
  final int? retryAfterSeconds;

  /// Changes on every result so the screen shows one message per attempt.
  final int seq;

  @override
  List<Object?> get props => [status, retryAfterSeconds, seq];
}

/// "Remind the approver" (Figma REQ-06 / 07). One request at a time: a second tap
/// while one is in flight is ignored.
class ApproverReminderCubit extends Cubit<ReminderState> {
  ApproverReminderCubit({required RemindApproverUseCase remindApprover})
      : _remind = remindApprover,
        super(const ReminderState());

  final RemindApproverUseCase _remind;

  Future<void> remind(String requestId) async {
    if (state.status == ReminderStatus.sending) return;
    emit(ReminderState(status: ReminderStatus.sending, seq: state.seq));
    final result = await _remind(requestId);
    if (isClosed) return;
    result.match(
      (failure) {
        final tooSoon = failure is ServerFailure && failure.code == 'RATE_LIMITED';
        final retry = tooSoon ? int.tryParse('${(failure).details['retryAfterSeconds']}') : null;
        emit(ReminderState(
          status: tooSoon ? ReminderStatus.tooSoon : ReminderStatus.failed,
          retryAfterSeconds: retry,
          seq: state.seq + 1,
        ));
      },
      (_) => emit(ReminderState(status: ReminderStatus.sent, seq: state.seq + 1)),
    );
  }
}
