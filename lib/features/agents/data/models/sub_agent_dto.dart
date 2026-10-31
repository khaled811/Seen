import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent.dart';

/// Wire shape of one sub-agency: `PortalSubAgent` of `portalAgents`
/// (`docs/api/mobile-api-reference.md`).
///
/// The API has no credit-limit, margin or agency-code fields for a sub-agency
/// (DECISIONS Q13), so those stay empty and the list shows the city instead.
class SubAgentDto {
  const SubAgentDto({
    required this.id,
    required this.name,
    required this.status,
    required this.city,
    required this.balanceAmount,
    this.ownerName,
    this.requestCount,
    this.monthRequestCount,
    this.canFund = false,
    this.canSuspend = false,
    this.canActivate = false,
    this.createdAt,
  });

  factory SubAgentDto.fromPortalJson(Map<String, dynamic> json) => SubAgentDto(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String? ?? '',
        city: json['city'] as String? ?? '',
        balanceAmount: json['balance'] as String?,
        ownerName: json['ownerName'] as String?,
        requestCount: json['requestCount'] as int?,
        monthRequestCount: json['monthRequestCount'] as int?,
        // Unknown permission flags fail closed: the controls stay hidden.
        canFund: json['canFund'] as bool? ?? false,
        canSuspend: json['canSuspend'] as bool? ?? false,
        canActivate: json['canActivate'] as bool? ?? false,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );

  /// `PortalSubAgent` selection shared by every query that reads one.
  static const portalFields = '''
    id name status city ownerName requestCount monthRequestCount balance currency
    canFund canSuspend canActivate createdAt
  ''';

  final String id;
  final String name;

  /// `active`, `suspended` or `pending`.
  final String status;
  final String city;

  /// Decimal string (e.g. `"1234.50"`), never parsed as `double`. Null when the
  /// server does not show it.
  final String? balanceAmount;
  final String? ownerName;
  final int? requestCount;
  final int? monthRequestCount;
  final bool canFund;
  final bool canSuspend;
  final bool canActivate;
  final DateTime? createdAt;

  SubAgent toEntity() => SubAgent(
        id: id,
        name: name,
        code: city,
        balanceCents: balanceAmount == null ? 0 : MoneyParser.centsFromDecimalString(balanceAmount!),
        isActive: status == 'active',
        invitePending: status == 'pending',
        ownerName: ownerName,
        requestCount: requestCount,
        monthRequestCount: monthRequestCount,
        canFund: canFund,
        canSuspend: canSuspend,
        canActivate: canActivate,
        balanceKnown: balanceAmount != null,
      );
}
