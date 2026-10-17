// "Request access" on the no-permission screen (Figma SYS-03).
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/system_status_usecases.dart';

enum AccessRequestStatus { idle, sending, sent, failed }

class AccessRequestState extends Equatable {
  const AccessRequestState([this.status = AccessRequestStatus.idle]);

  final AccessRequestStatus status;

  @override
  List<Object?> get props => [status];
}

class AccessRequestCubit extends Cubit<AccessRequestState> {
  AccessRequestCubit(this._request, {required this.area})
      : super(const AccessRequestState());

  final RequestAccessUseCase _request;

  /// What was refused, e.g. `wallet`.
  final String area;

  /// Ignored while sending and once sent (one request per refusal).
  Future<void> send() async {
    if (state.status == AccessRequestStatus.sending ||
        state.status == AccessRequestStatus.sent) return;
    emit(const AccessRequestState(AccessRequestStatus.sending));
    final result = await _request(area);
    if (isClosed) return;
    emit(AccessRequestState(result.isRight()
        ? AccessRequestStatus.sent
        : AccessRequestStatus.failed));
  }
}
