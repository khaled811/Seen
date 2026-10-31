import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_summary.dart';
import '../../domain/entities/requests_page.dart';
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
    this.pageSize = 30,
  })  : _getRequestsUseCase = getRequestsUseCase,
        _getRequestDetailUseCase = getRequestDetailUseCase,
        _cancelRequestUseCase = cancelRequestUseCase,
        super(const RequestsInitial()) {
    on<RequestsLoadRequested>(_onLoadRequested, transformer: droppable());
    // The latest chip wins: an older group's page must not land after it.
    on<RequestsFilterChanged>(_onFilterChanged, transformer: restartable());
    on<RequestsLoadMoreRequested>(_onLoadMore, transformer: droppable());
    // Live search: restartable + debounce, so only the last keystroke of a burst is searched.
    on<RequestsSearchChanged>(_onSearchChanged, transformer: restartable());
    on<RequestDetailRequested>(_onDetailRequested, transformer: droppable());
    on<RequestDetailAcknowledged>(_onDetailAcknowledged);
    on<RequestCancelSubmitted>(_onCancelSubmitted, transformer: droppable());
  }

  final GetRequestsUseCase _getRequestsUseCase;
  final GetRequestDetailUseCase _getRequestDetailUseCase;
  final CancelRequestUseCase _cancelRequestUseCase;

  /// Requests per page (the contract caps any list at 500; 30 keeps a page light).
  final int pageSize;

  Future<void> _onLoadRequested(
    RequestsLoadRequested event,
    Emitter<RequestsState> emit,
  ) async {
    final filter = switch (state) {
      RequestsLoaded(:final filter) => filter,
      _ => RequestsDashboardFilter.all,
    };
    emit(const RequestsLoading());
    final result = await _getRequestsUseCase(group: filter.group.wire, limit: pageSize);
    emit(
      result.match(
        (failure) => RequestsFailure(
          failure.message,
          offline: failure is NetworkFailure,
          reference: failure.reference,
          failure: failure,
        ),
        (page) => RequestsLoaded(requests: const [], filter: filter).withFirstPage(page),
      ),
    );
  }

  Future<void> _onFilterChanged(RequestsFilterChanged event, Emitter<RequestsState> emit) async {
    final current = state;
    if (current is! RequestsLoaded || current.filter == event.filter) return;
    emit(current.copyWith(filter: event.filter, requests: const [], hasMore: false, listLoading: true, clearListFailure: true));

    final result = await _getRequestsUseCase(group: event.filter.group.wire, limit: pageSize);
    final latest = state;
    if (latest is! RequestsLoaded || latest.filter != event.filter) return;
    emit(
      result.match(
        (failure) => latest.copyWith(listLoading: false, listFailure: failure),
        latest.withFirstPage,
      ),
    );
  }

  Future<void> _onLoadMore(RequestsLoadMoreRequested event, Emitter<RequestsState> emit) async {
    final current = state;
    if (current is! RequestsLoaded || !current.hasMore || current.loadingMore || current.listLoading) return;
    emit(current.copyWith(loadingMore: true, loadMoreFailed: false));

    final result = await _getRequestsUseCase(
      group: current.filter.group.wire,
      offset: current.requests.length,
      limit: pageSize,
    );
    final latest = state;
    if (latest is! RequestsLoaded || latest.filter != current.filter) return;
    emit(
      result.match(
        (_) => latest.copyWith(loadingMore: false, loadMoreFailed: true),
        (page) {
          // A new request can shift the pages: keep each id once.
          final known = {for (final r in latest.requests) r.id};
          return latest.copyWith(
            requests: [...latest.requests, for (final r in page.items) if (!known.contains(r.id)) r],
            hasMore: page.hasMore,
            loadingMore: false,
          );
        },
      ),
    );
  }

  static const searchDebounce = Duration(milliseconds: 250);

  Future<void> _onSearchChanged(RequestsSearchChanged event, Emitter<RequestsState> emit) async {
    final current = state;
    if (current is! RequestsLoaded) return;
    final query = event.query.trim();
    // Clearing the query applies at once: only typing is debounced.
    if (query.isEmpty) {
      emit(current.copyWith(searchQuery: event.query, searchResults: const [], searching: false, clearSearchFailure: true));
      return;
    }
    emit(current.copyWith(searchQuery: event.query, searching: true, clearSearchFailure: true));
    // A newer event restarts this handler; a cancelled emitter ignores emit().
    await Future<void>.delayed(searchDebounce);
    // Superseded by a newer keystroke during the debounce: do not search for this one.
    if (emit.isDone) return;

    final result = await _getRequestsUseCase(group: RequestsGroup.all.wire, search: query, limit: pageSize);
    final latest = state;
    if (latest is! RequestsLoaded || latest.searchQuery != event.query) return;
    emit(
      result.match(
        (failure) => latest.copyWith(searching: false, searchResults: const [], searchFailure: failure),
        (page) => latest.copyWith(searching: false, searchResults: page.items),
      ),
    );
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
          detailFailure: failure,
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

  /// Codes that mean "this request cannot be cancelled (any more)".
  static const _notCancellableCodes = {'NOT_CANCELLABLE', 'request_transition_invalid'};

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

    final result = await _cancelRequestUseCase(event.requestId, reason: event.reason);
    var outcome = result;

    // A timeout or a lost connection does not say whether the cancellation went
    // through. Never resend blindly: read the request and see.
    if (result case Left(:final value) when _isAmbiguous(value)) {
      final reread = await _getRequestDetailUseCase(event.requestId);
      if (reread case Right(value: final detail) when detail.status == RequestStatus.cancelled) {
        outcome = Right(detail);
      }
    }

    final latest = state;
    if (latest is! RequestsLoaded) return;
    emit(
      outcome.match(
        (failure) => latest.copyWith(
          cancelStatus: failure is ServerFailure && _notCancellableCodes.contains(failure.code)
              ? RequestCancelStatus.notCancellable
              : RequestCancelStatus.failure,
          cancelError: failure.message,
          cancelFailure: failure,
        ),
        (reloaded) {
          // Keep the dashboard list and the open detail in sync with the
          // backend's own answer rather than fabricating the new state: when the
          // reload failed, the only thing known is that the request is cancelled.
          final updated = reloaded ?? latest.detail?.copyWith(status: RequestStatus.cancelled);
          final requests = [
            for (final request in latest.requests)
              if (request.id == event.requestId && updated != null) _patchSummary(request, updated) else request,
          ];
          return latest.copyWith(requests: requests, detail: updated, cancelStatus: RequestCancelStatus.success);
        },
      ),
    );
  }

  static bool _isAmbiguous(Failure failure) =>
      failure is NetworkFailure || (failure is ServerFailure && failure.statusCode != null && failure.statusCode! >= 500);

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
        travelerNames: summary.travelerNames,
      );
}
