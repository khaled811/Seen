import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/service_interest_repository.dart';

enum InterestStatus { idle, sending, registered, failed }

class ServiceInterestState extends Equatable {
  const ServiceInterestState(this.status);

  final InterestStatus status;

  @override
  List<Object?> get props => [status];
}

/// The "Notify me when it launches" button of the coming-soon sheet (Figma BOOK-09).
class ServiceInterestCubit extends Cubit<ServiceInterestState> {
  ServiceInterestCubit(this._repository, {required this.serviceKey})
      : super(ServiceInterestState(
            _repository.alreadyRequested(serviceKey) ? InterestStatus.registered : InterestStatus.idle));

  final ServiceInterestRepository _repository;
  final String serviceKey;

  /// One request; a repeat tap while sending or after success is ignored.
  Future<void> notify() async {
    if (state.status == InterestStatus.sending || state.status == InterestStatus.registered) {
      return;
    }
    emit(const ServiceInterestState(InterestStatus.sending));
    final r = await _repository.notifyWhenAvailable(serviceKey);
    if (isClosed) {
      return;
    }
    emit(ServiceInterestState(r.isRight() ? InterestStatus.registered : InterestStatus.failed));
  }
}
