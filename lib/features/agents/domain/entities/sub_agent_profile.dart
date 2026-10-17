import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'sub_agent.dart';

/// One line of the sub-agent's own balance history (Figma AGT-04 "Balance
/// history"). Pure Dart.
class AgentLedgerEntry extends Equatable {
  const AgentLedgerEntry({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.isCredit,
    required this.createdAt,
  });

  final String id;

  /// Written by the backend ("Funding from the main agent", "SB-20484 · flight booking").
  final String title;

  /// Always positive; [isCredit] decides the sign.
  final int amountCents;
  final bool isCredit;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, title, amountCents, isCredit, createdAt];
}

/// A request the sub-agent submitted (the profile's "Agent requests").
class AgentRequestRow extends Equatable {
  const AgentRequestRow({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.status,
    required this.submittedAt,
  });

  final String id;
  final String referenceId;
  final String serviceName;
  final RequestStatus status;
  final DateTime submittedAt;

  @override
  List<Object?> get props =>
      [id, referenceId, serviceName, status, submittedAt];
}

/// Everything the profile screen shows about one sub-agent.
class SubAgentProfile extends Equatable {
  const SubAgentProfile({
    required this.agent,
    this.city,
    this.memberSince,
    this.monthlyRequestCount,
    this.inProgressRequestCount = 0,
    this.ledger = const [],
    this.requests = const [],
  });

  final SubAgent agent;
  final String? city;
  final DateTime? memberSince;
  final int? monthlyRequestCount;
  final int inProgressRequestCount;
  final List<AgentLedgerEntry> ledger;
  final List<AgentRequestRow> requests;

  @override
  List<Object?> get props => [
        agent,
        city,
        memberSince,
        monthlyRequestCount,
        inProgressRequestCount,
        ledger,
        requests
      ];
}
