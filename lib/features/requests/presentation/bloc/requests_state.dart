import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_summary.dart';

/// Dashboard filter buckets. `completed` covers the "Completed/Approved"
/// bucket from the brief — our confirmed `RequestStatus` enum (Task 01) has
/// no separate `approved` value, only `completed`; see the bloc's
/// `_statusesFor` mapping for the full reasoning.
enum RequestsDashboardFilter { all, pendingUnderReview, completed, actionRequired }

enum RequestDetailStatus { idle, loading, loaded, failure }

enum RequestCancelStatus { idle, submitting, success, failure }

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
  const RequestsFailure(this.message, {this.offline = false, this.reference});

  final String message;

  /// No connection / timeout (as opposed to a server error).
  final bool offline;

  /// Support reference (`502 · a91f`), when the server gave one.
  final String? reference;

  @override
  List<Object?> get props => [message, offline, reference];
}

final class RequestsLoaded extends RequestsState {
  const RequestsLoaded({
    required this.requests,
    this.filter = RequestsDashboardFilter.all,
    this.searchQuery = '',
    this.detailStatus = RequestDetailStatus.idle,
    this.detail,
    this.detailError,
    this.detailReady = false,
    this.cancelStatus = RequestCancelStatus.idle,
    this.cancelError,
  });

  final List<RequestSummary> requests;
  final RequestsDashboardFilter filter;

  /// Client-side substring search over `referenceId`/`serviceName` — not a
  /// server round trip, same as [filter].
  final String searchQuery;

  final RequestDetailStatus detailStatus;
  final RequestDetail? detail;
  final String? detailError;

  /// One-shot: true for exactly the emission right after a detail finishes
  /// loading; the UI navigates then dispatches `RequestDetailAcknowledged`
  /// to clear it (same pattern as the Services feature's `reviewReady`).
  final bool detailReady;

  final RequestCancelStatus cancelStatus;
  final String? cancelError;

  List<RequestSummary> get filteredRequests {
    final byBucket = switch (filter) {
      RequestsDashboardFilter.all => requests,
      RequestsDashboardFilter.pendingUnderReview =>
        requests.where((r) => _pendingStatuses.contains(r.status)).toList(),
      RequestsDashboardFilter.completed =>
        requests.where((r) => r.status == RequestStatus.completed).toList(),
      RequestsDashboardFilter.actionRequired =>
        requests.where((r) => r.status == RequestStatus.infoRequired).toList(),
    };
    final query = searchQuery.trim().toLowerCase();
    final bySearch = query.isEmpty
        ? byBucket
        : byBucket
            .where((r) =>
                r.referenceId.toLowerCase().contains(query) || r.serviceName.toLowerCase().contains(query))
            .toList();
    // `List.sort` isn't guaranteed stable, so ties (e.g. identical
    // submittedAt) are broken by original index to keep ordering
    // deterministic rather than relying on the sort algorithm's incidental
    // behavior.
    final indexed = bySearch.indexed.toList()
      ..sort((a, b) {
        final cmp = _compareRequests(a.$2, b.$2);
        return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  RequestsLoaded copyWith({
    List<RequestSummary>? requests,
    RequestsDashboardFilter? filter,
    String? searchQuery,
    RequestDetailStatus? detailStatus,
    RequestDetail? detail,
    String? detailError,
    bool clearDetailError = false,
    bool? detailReady,
    RequestCancelStatus? cancelStatus,
    String? cancelError,
    bool clearCancelError = false,
  }) =>
      RequestsLoaded(
        requests: requests ?? this.requests,
        filter: filter ?? this.filter,
        searchQuery: searchQuery ?? this.searchQuery,
        detailStatus: detailStatus ?? this.detailStatus,
        detail: detail ?? this.detail,
        detailError: clearDetailError ? null : (detailError ?? this.detailError),
        detailReady: detailReady ?? this.detailReady,
        cancelStatus: cancelStatus ?? this.cancelStatus,
        cancelError: clearCancelError ? null : (cancelError ?? this.cancelError),
      );

  @override
  List<Object?> get props => [
        requests,
        filter,
        searchQuery,
        detailStatus,
        detail,
        detailError,
        detailReady,
        cancelStatus,
        cancelError,
      ];
}

const _pendingStatuses = {
  RequestStatus.submitted,
  RequestStatus.pendingAgentApproval,
  RequestStatus.pendingManagementApproval,
  RequestStatus.underReview,
  RequestStatus.processing,
};

/// Action-required first, then SLA < 24h ascending (most urgent first), then
/// newest-submitted first. Evaluated against "now" at sort time, same as the
/// live SLA countdown elsewhere — this is a display order, not stored state.
int _compareRequests(RequestSummary a, RequestSummary b) {
  final now = DateTime.now();
  final actionA = a.status == RequestStatus.infoRequired;
  final actionB = b.status == RequestStatus.infoRequired;
  if (actionA != actionB) return actionA ? -1 : 1;

  final slaA = a.slaDeadline?.difference(now);
  final slaB = b.slaDeadline?.difference(now);
  final urgentA = slaA != null && slaA.inHours < 24;
  final urgentB = slaB != null && slaB.inHours < 24;
  if (urgentA != urgentB) return urgentA ? -1 : 1;
  if (urgentA && urgentB) return slaA.compareTo(slaB);

  return b.submittedAt.compareTo(a.submittedAt);
}
