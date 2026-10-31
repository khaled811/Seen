import '../../domain/entities/requests_page.dart';
import 'request_summary_dto.dart';

/// Wire shape of `PortalRequestList`, with its cards already mapped.
class RequestsPageDto {
  const RequestsPageDto({
    required this.items,
    required this.total,
    required this.hasMore,
    this.counts = const {},
    this.attentionCount = 0,
    this.attentionSoonestSeconds,
    this.hasAnyRequests = true,
    this.canCreate = true,
  });

  final List<RequestSummaryDto> items;
  final int total;
  final bool hasMore;
  final Map<String, int> counts;
  final int attentionCount;
  final int? attentionSoonestSeconds;
  final bool hasAnyRequests;
  final bool canCreate;

  RequestsPage toEntity() => RequestsPage(
        items: [for (final dto in items) dto.toEntity()],
        total: total,
        hasMore: hasMore,
        counts: counts,
        attentionCount: attentionCount,
        attentionSoonestSeconds: attentionSoonestSeconds,
        hasAnyRequests: hasAnyRequests,
        canCreate: canCreate,
      );
}
