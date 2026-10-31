import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/requests_page.dart';

/// What a server page of [all] requests looks like for a group and a search,
/// for fake repositories in tests (the server filters, searches and pages).
RequestsPage fakeRequestsPage(
  List<RequestSummary> all, {
  String group = 'all',
  String? search,
  int offset = 0,
  int limit = 30,
}) {
  bool inGroup(RequestSummary r, String g) => switch (g) {
        'all' => r.status != RequestStatus.draft,
        'processing' => const {
            RequestStatus.submitted,
            RequestStatus.pendingAgentApproval,
            RequestStatus.pendingManagementApproval,
            RequestStatus.underReview,
            RequestStatus.processing,
          }.contains(r.status),
        'action_needed' => r.status == RequestStatus.infoRequired,
        'completed' => r.status == RequestStatus.completed,
        'closed' => r.status == RequestStatus.rejected || r.status == RequestStatus.cancelled,
        'draft' => r.status == RequestStatus.draft,
        _ => false,
      };
  final query = search?.trim().toLowerCase() ?? '';
  final matching = [
    for (final r in all)
      if (inGroup(r, group) &&
          (query.isEmpty ||
              r.referenceId.toLowerCase().contains(query) ||
              r.serviceName.toLowerCase().contains(query) ||
              r.travelerNames.any((n) => n.toLowerCase().contains(query))))
        r,
  ];
  final page = matching.skip(offset).take(limit).toList();
  return RequestsPage(
    items: page,
    total: matching.length,
    hasMore: offset + page.length < matching.length,
    counts: {
      for (final g in const ['all', 'processing', 'action_needed', 'completed', 'closed']) g: all.where((r) => inGroup(r, g)).length,
    },
    attentionCount: all.where((r) => r.status == RequestStatus.infoRequired).length,
    hasAnyRequests: all.isNotEmpty,
  );
}
