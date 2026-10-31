import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

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
  const AgentsFailure(this.message, {this.failure});

  final String message;

  /// What went wrong, for the screen to word in the app's own language.
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure];
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
    this.approvalActionFailure,
    this.fundingStatus = FundingStatus.idle,
    this.fundingSubAgentId,
    this.fundingError,
    this.fundingFailure,
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
  final Failure? approvalActionFailure;

  final FundingStatus fundingStatus;
  final String? fundingSubAgentId;
  final String? fundingError;
  final Failure? fundingFailure;

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
    Failure? approvalActionFailure,
    bool clearApprovalActionError = false,
    FundingStatus? fundingStatus,
    String? fundingSubAgentId,
    bool clearFundingSubAgentId = false,
    String? fundingError,
    Failure? fundingFailure,
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
        approvalActionError: clearApprovalActionError
            ? null
            : (approvalActionError ?? this.approvalActionError),
        approvalActionFailure: clearApprovalActionError
            ? null
            : (approvalActionFailure ?? this.approvalActionFailure),
        fundingStatus: fundingStatus ?? this.fundingStatus,
        fundingSubAgentId: clearFundingSubAgentId
            ? null
            : (fundingSubAgentId ?? this.fundingSubAgentId),
        fundingError:
            clearFundingError ? null : (fundingError ?? this.fundingError),
        fundingFailure: clearFundingError ? null : (fundingFailure ?? this.fundingFailure),
        fundingReference: clearFundingError
            ? null
            : (fundingReference ?? this.fundingReference),
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
        approvalActionFailure,
        fundingStatus,
        fundingSubAgentId,
        fundingError,
        fundingFailure,
        fundingReference,
      ];
}
