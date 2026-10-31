import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent_profile.dart';
import 'sub_agent_dto.dart';

/// One sub-agency's profile, put together from three reads: the agency itself
/// (`portalAgents`), its wallet statement (`portalWallet(agentId:)`) and its
/// requests (`requests(agentId:)`). The statement and the requests are optional:
/// the server may refuse them to a user without that permission, and the
/// profile then simply shows without those sections.
class SubAgentProfileDto {
  const SubAgentProfileDto({
    required this.agent,
    this.ledger = const [],
    this.requests = const [],
  });

  final SubAgentDto agent;
  final List<LedgerEntryDto> ledger;
  final List<AgentRequestDto> requests;

  static const _finished = {'completed', 'rejected', 'cancelled', 'draft'};

  SubAgentProfile toEntity() => SubAgentProfile(
        agent: agent.toEntity(),
        city: agent.city.isEmpty ? null : agent.city,
        memberSince: agent.createdAt,
        monthlyRequestCount: agent.monthRequestCount,
        inProgressRequestCount: requests.where((r) => !_finished.contains(r.status)).length,
        ledger: [for (final e in ledger) e.toEntity()],
        requests: [for (final e in requests) e.toEntity()],
      );
}

/// A `PortalStatementRow` of the sub-agency's wallet.
class LedgerEntryDto {
  const LedgerEntryDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.isCredit,
    required this.createdAt,
    this.referenceCode,
  });

  factory LedgerEntryDto.fromJson(Map<String, dynamic> json) => LedgerEntryDto(
        id: json['id'] as String,
        type: json['type'] as String?,
        amount: json['amount'] as String,
        isCredit: json['direction'] == 'credit',
        createdAt: DateTime.parse(json['createdAt'] as String),
        referenceCode: json['referenceCode'] as String?,
      );

  static const statementFields = 'id type direction amount createdAt referenceCode';

  final String id;
  final String? type;

  /// Decimal string, positive.
  final String amount;
  final bool isCredit;
  final DateTime createdAt;
  final String? referenceCode;

  AgentLedgerEntry toEntity() => AgentLedgerEntry(
        id: id,
        type: TransactionType.fromValue(type),
        referenceCode: referenceCode,
        amountCents: MoneyParser.centsFromDecimalString(amount).abs(),
        isCredit: isCredit,
        createdAt: createdAt,
      );
}

/// A `Request` of the sub-agency.
class AgentRequestDto {
  const AgentRequestDto({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.status,
    required this.submittedAt,
  });

  factory AgentRequestDto.fromJson(Map<String, dynamic> json, AppLanguage language) {
    final service = json['serviceType'] as Map<String, dynamic>?;
    return AgentRequestDto(
      id: json['id'] as String,
      referenceId: json['referenceCode'] as String? ?? '',
      serviceName: language.pick(ar: service?['nameAr'] as String?, en: service?['nameEn'] as String?),
      status: json['status'] as String?,
      submittedAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static const requestFields = 'id referenceCode status createdAt serviceType { nameAr nameEn }';

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
