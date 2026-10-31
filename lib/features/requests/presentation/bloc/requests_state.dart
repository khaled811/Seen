import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_summary.dart';
import '../../domain/entities/requests_page.dart';

enum RequestsDashboardFilter { all, pendingUnderReview, completed, actionRequired }

/// Which server group each dashboard chip shows.
extension RequestsFilterGroup on RequestsDashboardFilter {
  RequestsGroup get group => switch (this) {
        RequestsDashboardFilter.all => RequestsGroup.all,
        RequestsDashboardFilter.pendingUnderReview => RequestsGroup.processing,
        RequestsDashboardFilter.completed => RequestsGroup.completed,
        RequestsDashboardFilter.actionRequired => RequestsGroup.actionNeeded,
      };
}

enum RequestDetailStatus { idle, loading, loaded, failure }

enum RequestCancelStatus { idle, submitting, success, failure, notCancellable }

sealed class RequestsState extends Equatable {
  const RequestsState();

  @override
  List<Object?> get props => [];
}

final class RequestsInitial extends RequestsState {
  const RequestsInitial();
}

final class RequestsLoading extends RequestsState {
  const RequestsLoading();
}

final class RequestsFailure extends RequestsState {
  const RequestsFailure(this.message, {this.offline = false, this.reference, this.failure});

  final String message;

  final bool offline;

  final String? reference;

  /// The underlying failure; the UI turns it into localized text.
  final Failure? failure;

  @override
  List<Object?> get props => [message, offline, reference, failure];
}

final class RequestsLoaded extends RequestsState {
  const RequestsLoaded({
    required this.requests,
    this.filter = RequestsDashboardFilter.all,
    this.searchQuery = '',
    this.searchResults = const [],
    this.searching = false,
    this.searchFailure,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.listLoading = false,
    this.listFailure,
    this.counts = const {},
    this.attentionCount,
    this.attentionSoonestSeconds,
    this.hasAnyRequests,
    this.canCreate = true,
    this.detailStatus = RequestDetailStatus.idle,
    this.detail,
    this.detailError,
    this.detailFailure,
    this.detailReady = false,
    this.cancelStatus = RequestCancelStatus.idle,
    this.cancelError,
    this.cancelFailure,
  });

  /// The loaded pages of the selected group, in the server's order (newest
  /// first). The server filters and pages; the app does not re-sort, so loading
  /// more never reshuffles what is on screen.
  final List<RequestSummary> requests;
  final RequestsDashboardFilter filter;

  final String searchQuery;

  /// The server's matches for [searchQuery] (first page).
  final List<RequestSummary> searchResults;
  final bool searching;
  final Failure? searchFailure;

  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// A group is being loaded (the chip was just changed).
  final bool listLoading;
  final Failure? listFailure;

  /// Requests per group, from the server, keyed by the group's wire value.
  final Map<String, int> counts;

  /// The server's own "needs action" figures (`attention`).
  final int? attentionCount;
  final int? attentionSoonestSeconds;

  /// False when the agency has never filed a request; null while unknown.
  final bool? hasAnyRequests;

  /// Whether this person may file a request.
  final bool canCreate;

  final RequestDetailStatus detailStatus;
  final RequestDetail? detail;
  final String? detailError;
  final Failure? detailFailure;

  final bool detailReady;

  final RequestCancelStatus cancelStatus;
  final String? cancelError;
  final Failure? cancelFailure;

  /// The list the dashboard shows.
  List<RequestSummary> get filteredRequests => requests;

  /// How many requests a chip stands for: the server's count, or (for a state
  /// built without one) what is loaded.
  int countFor(RequestsDashboardFilter f) {
    final fromServer = counts[f.group.wire];
    if (fromServer != null) return fromServer;
    return switch (f) {
      RequestsDashboardFilter.all => requests.length,
      RequestsDashboardFilter.pendingUnderReview => requests
          .where((r) =>
              r.status == RequestStatus.submitted ||
              r.status == RequestStatus.underReview ||
              r.status == RequestStatus.processing)
          .length,
      RequestsDashboardFilter.actionRequired => requests.where((r) => r.status == RequestStatus.infoRequired).length,
      RequestsDashboardFilter.completed => requests.where((r) => r.status == RequestStatus.completed).length,
    };
  }

  RequestsLoaded copyWith({
    List<RequestSummary>? requests,
    RequestsDashboardFilter? filter,
    String? searchQuery,
    List<RequestSummary>? searchResults,
    bool? searching,
    Failure? searchFailure,
    bool clearSearchFailure = false,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    bool? listLoading,
    Failure? listFailure,
    bool clearListFailure = false,
    Map<String, int>? counts,
    int? attentionCount,
    int? attentionSoonestSeconds,
    bool? hasAnyRequests,
    bool? canCreate,
    RequestDetailStatus? detailStatus,
    RequestDetail? detail,
    String? detailError,
    Failure? detailFailure,
    bool clearDetailError = false,
    bool? detailReady,
    RequestCancelStatus? cancelStatus,
    String? cancelError,
    Failure? cancelFailure,
    bool clearCancelError = false,
  }) =>
      RequestsLoaded(
        requests: requests ?? this.requests,
        filter: filter ?? this.filter,
        searchQuery: searchQuery ?? this.searchQuery,
        searchResults: searchResults ?? this.searchResults,
        searching: searching ?? this.searching,
        searchFailure: clearSearchFailure ? null : (searchFailure ?? this.searchFailure),
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        listLoading: listLoading ?? this.listLoading,
        listFailure: clearListFailure ? null : (listFailure ?? this.listFailure),
        counts: counts ?? this.counts,
        attentionCount: attentionCount ?? this.attentionCount,
        attentionSoonestSeconds: attentionSoonestSeconds ?? this.attentionSoonestSeconds,
        hasAnyRequests: hasAnyRequests ?? this.hasAnyRequests,
        canCreate: canCreate ?? this.canCreate,
        detailStatus: detailStatus ?? this.detailStatus,
        detail: detail ?? this.detail,
        detailError: clearDetailError ? null : (detailError ?? this.detailError),
        detailFailure: clearDetailError ? null : (detailFailure ?? this.detailFailure),
        detailReady: detailReady ?? this.detailReady,
        cancelStatus: cancelStatus ?? this.cancelStatus,
        cancelError: clearCancelError ? null : (cancelError ?? this.cancelError),
        cancelFailure: clearCancelError ? null : (cancelFailure ?? this.cancelFailure),
      );

  /// Applies a freshly loaded [page] as the start of the list.
  RequestsLoaded withFirstPage(RequestsPage page) => copyWith(
        requests: page.items,
        hasMore: page.hasMore,
        loadingMore: false,
        loadMoreFailed: false,
        listLoading: false,
        clearListFailure: true,
        counts: page.counts.isEmpty ? counts : page.counts,
        attentionCount: page.attentionCount,
        attentionSoonestSeconds: page.attentionSoonestSeconds,
        hasAnyRequests: page.hasAnyRequests,
        canCreate: page.canCreate,
      );

  @override
  List<Object?> get props => [
        requests,
        filter,
        searchQuery,
        searchResults,
        searching,
        searchFailure,
        hasMore,
        loadingMore,
        loadMoreFailed,
        listLoading,
        listFailure,
        counts,
        attentionCount,
        attentionSoonestSeconds,
        hasAnyRequests,
        canCreate,
        detailStatus,
        detail,
        detailError,
        detailFailure,
        detailReady,
        cancelStatus,
        cancelError,
        cancelFailure,
      ];
}
