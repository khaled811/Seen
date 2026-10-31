import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/cancel_top_up_usecase.dart';

enum TopUpCancelStatus { idle, submitting, success, notCancellable, failure }

class TopUpCancelState extends Equatable {
  const TopUpCancelState({this.status = TopUpCancelStatus.idle, this.message, this.failure});

  final TopUpCancelStatus status;

  /// The server's message for [TopUpCancelStatus.failure].
  final String? message;

  /// The failure behind [message] (shown localized).
  final Failure? failure;

  @override
  List<Object?> get props => [status, message, failure];
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
        // The API has no operation to withdraw a top-up request, so it can never
        // be cancelled from the app: the same message as "already decided".
        failure is ServerFailure && (failure.code == 'NOT_CANCELLABLE' || failure.code == 'unsupported_operation')
            ? const TopUpCancelState(status: TopUpCancelStatus.notCancellable)
            : TopUpCancelState(status: TopUpCancelStatus.failure, message: failure.message, failure: failure),
      ),
      (_) => emit(const TopUpCancelState(status: TopUpCancelStatus.success)),
    );
  }
}
