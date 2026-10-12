import 'package:equatable/equatable.dart';

import 'requests_state.dart' show RequestsDashboardFilter;

sealed class RequestsEvent extends Equatable {
  const RequestsEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on the dashboard's entry, and on pull-to-refresh.
final class RequestsLoadRequested extends RequestsEvent {
  const RequestsLoadRequested();
}

final class RequestsFilterChanged extends RequestsEvent {
  const RequestsFilterChanged(this.filter);

  final RequestsDashboardFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Client-side substring search over the already-loaded requests (matches
/// `referenceId` or `serviceName`) — not a server round trip, same as the
/// dashboard filter.
final class RequestsSearchChanged extends RequestsEvent {
  const RequestsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Fetches [requestId]'s detail; the UI navigates once it's loaded.
final class RequestDetailRequested extends RequestsEvent {
  const RequestDetailRequested(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

/// Dispatched by the UI once it has acted on a freshly-loaded detail (i.e.
/// navigated to the detail screen), so returning to the dashboard doesn't
/// re-trigger navigation.
final class RequestDetailAcknowledged extends RequestsEvent {
  const RequestDetailAcknowledged();
}

final class RequestCancelSubmitted extends RequestsEvent {
  const RequestCancelSubmitted(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}
