import 'package:equatable/equatable.dart';

/// One request submitted by a sub-agent, awaiting the master agent's
/// approval gate (`RequestStatus.pendingAgentApproval`). This list is
/// already scoped to that status by the repository — see
/// `AgentsRepository.getPendingApprovalRequests`.
class SubAgentRequestSummary extends Equatable {
  const SubAgentRequestSummary({
    required this.id,
    required this.referenceId,
    required this.subAgentName,
    required this.serviceName,
    required this.travelerCount,
    required this.totalPriceCents,
    required this.submittedAt,
  });

  final String id;
  final String referenceId;
  final String subAgentName;
  final String serviceName;
  final int travelerCount;
  final int totalPriceCents;
  final DateTime submittedAt;

  @override
  List<Object?> get props => [
        id,
        referenceId,
        subAgentName,
        serviceName,
        travelerCount,
        totalPriceCents,
        submittedAt,
      ];
}
