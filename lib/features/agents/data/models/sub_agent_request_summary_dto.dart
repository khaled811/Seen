import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent_request_summary.dart';

/// Wire shape of one request waiting for the main agent's approval: a `Request`
/// read with `requests(status: "pending_agent_approval")`.
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

  static const requestFields = '''
    id referenceCode createdAt sellingPrice
    serviceType { nameAr nameEn }
    agent { name }
    travelers { id }
  ''';

  factory SubAgentRequestSummaryDto.fromJson(Map<String, dynamic> json, AppLanguage language) {
    final service = json['serviceType'] as Map<String, dynamic>?;
    return SubAgentRequestSummaryDto(
      id: json['id'] as String,
      referenceId: json['referenceCode'] as String? ?? '',
      subAgentName: (json['agent'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      serviceName: language.pick(ar: service?['nameAr'] as String?, en: service?['nameEn'] as String?),
      travelerCount: (json['travelers'] as List<dynamic>? ?? const []).length,
      totalPriceAmount: json['sellingPrice'] as String?,
      submittedAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String referenceId;
  final String subAgentName;
  final String serviceName;
  final int travelerCount;

  /// Decimal string (e.g. `"450.00"`), never parsed as `double`; null when the
  /// server does not show a price.
  final String? totalPriceAmount;
  final DateTime submittedAt;

  SubAgentRequestSummary toEntity() => SubAgentRequestSummary(
        id: id,
        referenceId: referenceId,
        subAgentName: subAgentName,
        serviceName: serviceName,
        travelerCount: travelerCount,
        totalPriceCents: totalPriceAmount == null ? 0 : MoneyParser.centsFromDecimalString(totalPriceAmount!),
        submittedAt: submittedAt,
      );
}
