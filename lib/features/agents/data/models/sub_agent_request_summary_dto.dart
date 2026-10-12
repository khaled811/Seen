import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent_request_summary.dart';

/// Wire shape of one pending-agent-approval request row.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema.
class SubAgentRequestSummaryDto {
  const SubAgentRequestSummaryDto({
    required this.id,
    required this.referenceId,
    required this.subAgentName,
    required this.serviceName,
    required this.travelerCount,
    required this.totalPriceAmount,
    required this.submittedAt,
  });

  factory SubAgentRequestSummaryDto.fromJson(Map<String, dynamic> json) =>
      SubAgentRequestSummaryDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        subAgentName: json['subAgentName'] as String,
        serviceName: json['serviceName'] as String,
        travelerCount: json['travelerCount'] as int,
        totalPriceAmount: json['totalPriceAmount'] as String,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );

  final String id;
  final String referenceId;
  final String subAgentName;
  final String serviceName;
  final int travelerCount;

  /// Decimal string (e.g. `"450.00"`) — never parsed as `double`.
  final String totalPriceAmount;
  final DateTime submittedAt;

  SubAgentRequestSummary toEntity() => SubAgentRequestSummary(
        id: id,
        referenceId: referenceId,
        subAgentName: subAgentName,
        serviceName: serviceName,
        travelerCount: travelerCount,
        totalPriceCents: MoneyParser.centsFromDecimalString(totalPriceAmount),
        submittedAt: submittedAt,
      );
}
