import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/cancel_top_up_usecase.dart';

enum TopUpCancelStatus { idle, submitting, success, notCancellable, failure }

class TopUpCancelState extends Equatable {
  const TopUpCancelState({this.status = TopUpCancelStatus.idle, this.message});

  final TopUpCancelStatus status;

  /// The server's message for [TopUpCancelStatus.failure].
  final String? message;

  @override
  List<Object?> get props => [status, message];
}

/// "Cancel top-up request" (Figma WAL-02). One request at a time: a second tap
/// while one is in flight is ignored.
class TopUpCancelCubit extends Cubit<TopUpCancelState> {
  TopUpCancelCubit({required CancelTopUpUseCase cancelTopUp})
      : _cancelTopUp = cancelTopUp,
        super(const TopUpCancelState());

  final CancelTopUpUseCase _cancelTopUp;

  Future<void> cancel(String transactionId) async {
    if (state.status == TopUpCancelStatus.submitting) return;
    emit(const TopUpCancelState(status: TopUpCancelStatus.submitting));
    final result = await _cancelTopUp(transactionId);
    if (isClosed) return;
    result.match(
      (failure) => emit(
        failure is ServerFailure && failure.code == 'NOT_CANCELLABLE'
            ? const TopUpCancelState(status: TopUpCancelStatus.notCancellable)
            : TopUpCancelState(status: TopUpCancelStatus.failure, message: failure.message),
      ),
      (_) => emit(const TopUpCancelState(status: TopUpCancelStatus.success)),
    );
  }
}
