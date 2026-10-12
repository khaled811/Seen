import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_summary.dart';
import '../../domain/usecases/cancel_request_usecase.dart';
import '../../domain/usecases/get_request_detail_usecase.dart';
import '../../domain/usecases/get_requests_usecase.dart';
import 'requests_event.dart';
import 'requests_state.dart';

class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  RequestsBloc({
    required GetRequestsUseCase getRequestsUseCase,
    required GetRequestDetailUseCase getRequestDetailUseCase,
    required CancelRequestUseCase cancelRequestUseCase,
  })  : _getRequestsUseCase = getRequestsUseCase,
        _getRequestDetailUseCase = getRequestDetailUseCase,
        _cancelRequestUseCase = cancelRequestUseCase,
        super(const RequestsInitial()) {
    on<RequestsLoadRequested>(_onLoadRequested, transformer: droppable());
    on<RequestsFilterChanged>(_onFilterChanged);
    on<RequestsSearchChanged>(_onSearchChanged);
    on<RequestDetailRequested>(_onDetailRequested, transformer: droppable());
    on<RequestDetailAcknowledged>(_onDetailAcknowledged);
    on<RequestCancelSubmitted>(_onCancelSubmitted, transformer: droppable());
  }

  final GetRequestsUseCase _getRequestsUseCase;
  final GetRequestDetailUseCase _getRequestDetailUseCase;
  final CancelRequestUseCase _cancelRequestUseCase;

  Future<void> _onLoadRequested(
    RequestsLoadRequested event,
    Emitter<RequestsState> emit,
  ) async {
    emit(const RequestsLoading());
    final result = await _getRequestsUseCase();
    emit(
      result.match(
        (failure) => RequestsFailure(failure.message),
        (requests) => RequestsLoaded(requests: requests),
      ),
    );
  }

  void _onFilterChanged(RequestsFilterChanged event, Emitter<RequestsState> emit) {
    final current = state;
    if (current is! RequestsLoaded) return;
    emit(current.copyWith(filter: event.filter));
  }

  void _onSearchChanged(RequestsSearchChanged event, Emitter<RequestsState> emit) {
    final current = state;
    if (current is! RequestsLoaded) return;
    emit(current.copyWith(searchQuery: event.query));
  }

  Future<void> _onDetailRequested(
    RequestDetailRequested event,
    Emitter<RequestsState> emit,
  ) async {
    final current = state;
    if (current is! RequestsLoaded) return;

    emit(
      current.copyWith(
        detailStatus: RequestDetailStatus.loading,
        clearDetailError: true,
        detailReady: false,
      ),
    );

    final result = await _getRequestDetailUseCase(event.requestId);
    final latest = state;
    if (latest is! RequestsLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          detailStatus: RequestDetailStatus.failure,
          detailError: failure.message,
        ),
        (detail) => latest.copyWith(
          detailStatus: RequestDetailStatus.loaded,
          detail: detail,
          detailReady: true,
          cancelStatus: RequestCancelStatus.idle,
        ),
      ),
    );
  }

  void _onDetailAcknowledged(
    RequestDetailAcknowledged event,
    Emitter<RequestsState> emit,
  ) {
    final current = state;
    if (current is! RequestsLoaded) return;
    emit(current.copyWith(detailReady: false));
  }

  Future<void> _onCancelSubmitted(
    RequestCancelSubmitted event,
    Emitter<RequestsState> emit,
  ) async {
    final current = state;
    if (current is! RequestsLoaded) return;

    emit(
      current.copyWith(
        cancelStatus: RequestCancelStatus.submitting,
        clearCancelError: true,
      ),
    );

    final result = await _cancelRequestUseCase(event.requestId);
    final latest = state;
    if (latest is! RequestsLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          cancelStatus: RequestCancelStatus.failure,
          cancelError: failure.message,
        ),
        (updatedDetail) {
          // Keep the dashboard list and the open detail in sync with the
          // single source of truth (the backend's response), rather than
          // fabricating the new status client-side.
          final requests = [
            for (final request in latest.requests)
              if (request.id == updatedDetail.id)
                _patchSummary(request, updatedDetail)
              else
                request,
          ];
          return latest.copyWith(
            requests: requests,
            detail: updatedDetail,
            cancelStatus: RequestCancelStatus.success,
          );
        },
      ),
    );
  }

  /// Re-derives a dashboard row's status/SLA fields from the freshly
  /// cancelled detail, keeping everything else (reference, service, price,
  /// submission date) as already known — avoids a full list refetch for one
  /// field change.
  RequestSummary _patchSummary(RequestSummary summary, RequestDetail detail) =>
      RequestSummary(
        id: summary.id,
        referenceId: summary.referenceId,
        serviceName: summary.serviceName,
        travelerCount: summary.travelerCount,
        totalPriceCents: summary.totalPriceCents,
        status: detail.status,
        submittedAt: summary.submittedAt,
        slaDeadline: detail.slaDeadline,
      );
}
