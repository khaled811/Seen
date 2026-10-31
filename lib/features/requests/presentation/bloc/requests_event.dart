import 'package:equatable/equatable.dart';

import '../../domain/entities/cancel_reason.dart';
import 'requests_state.dart' show RequestsDashboardFilter;

sealed class RequestsEvent extends Equatable {
  const RequestsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads (or reloads) the first page of the selected group.
final class RequestsLoadRequested extends RequestsEvent {
  const RequestsLoadRequested();
}

/// Shows another group: the server filters, so this loads that group's first page.
final class RequestsFilterChanged extends RequestsEvent {
  const RequestsFilterChanged(this.filter);

  final RequestsDashboardFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// The end of the list came into view: load the next page.
final class RequestsLoadMoreRequested extends RequestsEvent {
  const RequestsLoadMoreRequested();
}

/// The search text changed; the server searches (debounced).
final class RequestsSearchChanged extends RequestsEvent {
  const RequestsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class RequestDetailRequested extends RequestsEvent {
  const RequestDetailRequested(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class RequestDetailAcknowledged extends RequestsEvent {
  const RequestDetailAcknowledged();
}

final class RequestCancelSubmitted extends RequestsEvent {
  const RequestCancelSubmitted(this.requestId, {this.reason});

  final String requestId;
  final CancelReason? reason;

  @override
  List<Object?> get props => [requestId, reason];
}
