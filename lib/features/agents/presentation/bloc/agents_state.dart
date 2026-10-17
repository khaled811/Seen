import 'package:equatable/equatable.dart';

import '../../../wallet/domain/entities/wallet_balance.dart';
import '../../domain/entities/sub_agent.dart';
import '../../domain/entities/sub_agent_request_summary.dart';

enum ApprovalActionStatus { idle, submitting, success, failure }

/// Which action a submitting/completed [ApprovalActionStatus] refers to —
/// lets the UI show "Approved"/"Rejected" rather than one generic message.
enum ApprovalActionKind { none, approve, reject }

enum FundingStatus { idle, submitting, success, failure }

sealed class AgentsState extends Equatable {
  const AgentsState();

  @override
  List<Object?> get props => [];
}

final class AgentsInitial extends AgentsState {
  const AgentsInitial();
}

final class AgentsLoading extends AgentsState {
  const AgentsLoading();
}

final class AgentsFailure extends AgentsState {
  const AgentsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class AgentsLoaded extends AgentsState {
  const AgentsLoaded({
    required this.subAgents,
    required this.pendingRequests,
    this.masterWalletBalance,
    this.masterWalletBalanceLoading = false,
    this.approvalActionStatus = ApprovalActionStatus.idle,
    this.approvalActionKind = ApprovalActionKind.none,
    this.approvalActionRequestId,
    this.approvalActionError,
    this.fundingStatus = FundingStatus.idle,
    this.fundingSubAgentId,
    this.fundingError,
    this.fundingReference,
  });

  final List<SubAgent> subAgents;
  final List<SubAgentRequestSummary> pendingRequests;

  /// The logged-in master agent's own wallet — reused from Task 06 to
  /// validate transfer amounts against it.
  final WalletBalance? masterWalletBalance;
  final bool masterWalletBalanceLoading;

  final ApprovalActionStatus approvalActionStatus;
  final ApprovalActionKind approvalActionKind;
  final String? approvalActionRequestId;
  final String? approvalActionError;

  final FundingStatus fundingStatus;
  final String? fundingSubAgentId;
  final String? fundingError;

  /// Support reference of the failed transfer (`502 · a91f`), when known.
  final String? fundingReference;

  AgentsLoaded copyWith({
    List<SubAgent>? subAgents,
    List<SubAgentRequestSummary>? pendingRequests,
    WalletBalance? masterWalletBalance,
    bool? masterWalletBalanceLoading,
    ApprovalActionStatus? approvalActionStatus,
    ApprovalActionKind? approvalActionKind,
    String? approvalActionRequestId,
    bool clearApprovalActionRequestId = false,
    String? approvalActionError,
    bool clearApprovalActionError = false,
    FundingStatus? fundingStatus,
    String? fundingSubAgentId,
    bool clearFundingSubAgentId = false,
    String? fundingError,
    bool clearFundingError = false,
    String? fundingReference,
  }) =>
      AgentsLoaded(
        subAgents: subAgents ?? this.subAgents,
        pendingRequests: pendingRequests ?? this.pendingRequests,
        masterWalletBalance: masterWalletBalance ?? this.masterWalletBalance,
        masterWalletBalanceLoading:
            masterWalletBalanceLoading ?? this.masterWalletBalanceLoading,
        approvalActionStatus: approvalActionStatus ?? this.approvalActionStatus,
        approvalActionKind: approvalActionKind ?? this.approvalActionKind,
        approvalActionRequestId: clearApprovalActionRequestId
            ? null
            : (approvalActionRequestId ?? this.approvalActionRequestId),
        approvalActionError:
            clearApprovalActionError ? null : (approvalActionError ?? this.approvalActionError),
        fundingStatus: fundingStatus ?? this.fundingStatus,
        fundingSubAgentId:
            clearFundingSubAgentId ? null : (fundingSubAgentId ?? this.fundingSubAgentId),
        fundingError: clearFundingError ? null : (fundingError ?? this.fundingError),
        fundingReference: clearFundingError ? null : (fundingReference ?? this.fundingReference),
      );

  @override
  List<Object?> get props => [
        subAgents,
        pendingRequests,
        masterWalletBalance,
        masterWalletBalanceLoading,
        approvalActionStatus,
        approvalActionKind,
        approvalActionRequestId,
        approvalActionError,
        fundingStatus,
        fundingSubAgentId,
        fundingError,
        fundingReference,
      ];
}
