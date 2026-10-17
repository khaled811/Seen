import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent_profile.dart';
import 'sub_agent_dto.dart';

/// Wire shape of one sub-agent's profile.
///
/// TODO(backend-contract): placeholder field names (docs/BACKEND_MIGRATION_GAPS.md, section 17).
class SubAgentProfileDto {
  const SubAgentProfileDto({
    required this.agent,
    this.city,
    this.memberSince,
    this.monthlyRequestCount,
    this.inProgressRequestCount = 0,
    this.ledger = const [],
    this.requests = const [],
  });

  factory SubAgentProfileDto.fromJson(Map<String, dynamic> json) => SubAgentProfileDto(
        agent: SubAgentDto.fromJson(json['agent'] as Map<String, dynamic>),
        city: json['city'] as String?,
        memberSince: json['memberSince'] == null ? null : DateTime.parse(json['memberSince'] as String),
        monthlyRequestCount: json['monthlyRequestCount'] as int?,
        inProgressRequestCount: json['inProgressRequestCount'] as int? ?? 0,
        ledger: [
          for (final e in (json['ledger'] as List<dynamic>? ?? const []))
            LedgerEntryDto.fromJson(e as Map<String, dynamic>),
        ],
        requests: [
          for (final e in (json['requests'] as List<dynamic>? ?? const []))
            AgentRequestDto.fromJson(e as Map<String, dynamic>),
        ],
      );

  final SubAgentDto agent;
  final String? city;
  final DateTime? memberSince;
  final int? monthlyRequestCount;
  final int inProgressRequestCount;
  final List<LedgerEntryDto> ledger;
  final List<AgentRequestDto> requests;

  SubAgentProfile toEntity() => SubAgentProfile(
        agent: agent.toEntity(),
        city: city,
        memberSince: memberSince,
        monthlyRequestCount: monthlyRequestCount,
        inProgressRequestCount: inProgressRequestCount,
        ledger: [for (final e in ledger) e.toEntity()],
        requests: [for (final e in requests) e.toEntity()],
      );
}

class LedgerEntryDto {
  const LedgerEntryDto({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.createdAt,
  });

  factory LedgerEntryDto.fromJson(Map<String, dynamic> json) => LedgerEntryDto(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: json['amount'] as String,
        isCredit: json['side'] == 'credit',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String title;

  /// Decimal string, positive.
  final String amount;
  final bool isCredit;
  final DateTime createdAt;

  AgentLedgerEntry toEntity() => AgentLedgerEntry(
        id: id,
        title: title,
        amountCents: MoneyParser.centsFromDecimalString(amount).abs(),
        isCredit: isCredit,
        createdAt: createdAt,
      );
}

class AgentRequestDto {
  const AgentRequestDto({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.status,
    required this.submittedAt,
  });

  factory AgentRequestDto.fromJson(Map<String, dynamic> json) => AgentRequestDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        serviceName: json['serviceName'] as String,
        status: json['status'] as String?,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );

  final String id;
  final String referenceId;
  final String serviceName;
  final String? status;
  final DateTime submittedAt;

  AgentRequestRow toEntity() => AgentRequestRow(
        id: id,
        referenceId: referenceId,
        serviceName: serviceName,
        status: RequestStatus.fromValue(status),
        submittedAt: submittedAt,
      );
}
