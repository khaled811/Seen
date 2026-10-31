import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../requests/domain/entities/request_summary.dart';
import '../../../requests/domain/entities/requests_page.dart';
import '../../../requests/domain/usecases/get_requests_usecase.dart';

sealed class DraftsEvent extends Equatable {
  const DraftsEvent();

  @override
  List<Object?> get props => [];
}

final class DraftsLoadRequested extends DraftsEvent {
  const DraftsLoadRequested();
}

final class DraftsLoadMoreRequested extends DraftsEvent {
  const DraftsLoadMoreRequested();
}

enum DraftsStatus { loading, ready, failed }

class DraftsState extends Equatable {
  const DraftsState({
    this.status = DraftsStatus.loading,
    this.drafts = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final DraftsStatus status;

  /// The agent's server drafts (`portalRequests(group: draft)`), newest first as
  /// the server orders them.
  final List<RequestSummary> drafts;
  final bool hasMore;
  final bool loadingMore;
  final Failure? failure;

  DraftsState copyWith({
    DraftsStatus? status,
    List<RequestSummary>? drafts,
    bool? hasMore,
    bool? loadingMore,
    Failure? failure,
  }) =>
      DraftsState(
        status: status ?? this.status,
        drafts: drafts ?? this.drafts,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        failure: failure ?? this.failure,
      );

  @override
  List<Object?> get props => [status, drafts, hasMore, loadingMore, failure];
}

class DraftsBloc extends Bloc<DraftsEvent, DraftsState> {
  DraftsBloc({
    required GetRequestsUseCase getRequests,
    this.pageSize = 30,
  })  : _getRequests = getRequests,
        super(const DraftsState()) {
    on<DraftsLoadRequested>(_onLoad, transformer: restartable());
    on<DraftsLoadMoreRequested>(_onLoadMore, transformer: droppable());
  }

  final GetRequestsUseCase _getRequests;
  final int pageSize;

  Future<void> _onLoad(DraftsLoadRequested event, Emitter<DraftsState> emit) async {
    final result = await _getRequests(group: RequestsGroup.draft.wire, limit: pageSize);
    result.match(
      (failure) => emit(state.copyWith(status: DraftsStatus.failed, failure: failure)),
      (page) => emit(DraftsState(
        status: DraftsStatus.ready,
        drafts: page.items,
        hasMore: page.hasMore,
      )),
    );
  }

  Future<void> _onLoadMore(DraftsLoadMoreRequested event, Emitter<DraftsState> emit) async {
    if (state.status != DraftsStatus.ready || !state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await _getRequests(group: RequestsGroup.draft.wire, offset: state.drafts.length, limit: pageSize);
    result.match(
      (failure) => emit(state.copyWith(loadingMore: false)),
      (page) {
        // A draft filed or removed meanwhile can shift the pages: keep each id once.
        final known = {for (final d in state.drafts) d.id};
        emit(state.copyWith(
          drafts: [...state.drafts, for (final d in page.items) if (!known.contains(d.id)) d],
          hasMore: page.hasMore,
          loadingMore: false,
        ));
      },
    );
  }
}
