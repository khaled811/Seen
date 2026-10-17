import 'package:equatable/equatable.dart';

sealed class AgentsEvent extends Equatable {
  const AgentsEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on entry, and on pull-to-refresh: loads sub-agents, pending
/// approval requests, and the master agent's own wallet balance together.
final class AgentsLoadRequested extends AgentsEvent {
  const AgentsLoadRequested();
}

final class SubAgentRequestApproveSubmitted extends AgentsEvent {
  const SubAgentRequestApproveSubmitted(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class SubAgentRequestRejectSubmitted extends AgentsEvent {
  const SubAgentRequestRejectSubmitted({required this.requestId, required this.reason});

  final String requestId;
  final String reason;

  @override
  List<Object?> get props => [requestId, reason];
}

/// Dispatched by the UI once it has shown a completed approve/reject's
/// success/failure feedback, so the status doesn't linger.
final class ApprovalStatusCleared extends AgentsEvent {
  const ApprovalStatusCleared();
}

final class SubAgentWalletFundingSubmitted extends AgentsEvent {
  const SubAgentWalletFundingSubmitted({
    required this.subAgentId,
    required this.amountCents,
    this.note,
  });

  final String subAgentId;
  final int amountCents;

  /// Optional free-text note sent with the transfer.
  final String? note;

  @override
  List<Object?> get props => [subAgentId, amountCents, note];
}

final class FundingStatusCleared extends AgentsEvent {
  const FundingStatusCleared();
}
