import 'package:equatable/equatable.dart';

import 'request_summary.dart';

/// The request groups the server filters by (`portalRequests(group: …)`).
enum RequestsGroup {
  all('all'),
  newlyFiled('new'),
  processing('processing'),
  actionNeeded('action_needed'),
  completed('completed'),
  closed('closed'),
  draft('draft');

  const RequestsGroup(this.wire);

  final String wire;
}

/// One page of the agency's requests with the numbers the dashboard shows next
/// to them. Everything here is computed by the server for the whole list, not
/// for the loaded page.
class RequestsPage extends Equatable {
  const RequestsPage({
    required this.items,
    required this.total,
    required this.hasMore,
    this.counts = const {},
    this.attentionCount = 0,
    this.attentionSoonestSeconds,
    this.hasAnyRequests = true,
    this.canCreate = true,
  });

  final List<RequestSummary> items;

  /// How many requests match the group (and search), over all pages.
  final int total;
  final bool hasMore;

  /// Requests per group (`filters`), keyed by the group's wire value.
  final Map<String, int> counts;

  /// Requests that need the agency to act, and the seconds left on the
  /// soonest deadline (`attention`).
  final int attentionCount;
  final int? attentionSoonestSeconds;

  /// False when the agency has never filed a request (the empty state).
  final bool hasAnyRequests;

  /// Whether this person may file a request.
  final bool canCreate;

  @override
  List<Object?> get props =>
      [items, total, hasMore, counts, attentionCount, attentionSoonestSeconds, hasAnyRequests, canCreate];
}
