import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../wallet/domain/usecases/get_wallet_balance_usecase.dart';
import '../../domain/entities/sub_agent.dart';
import '../../domain/entities/sub_agent_request_summary.dart';
import '../../domain/usecases/approve_sub_agent_request_usecase.dart';
import '../../domain/usecases/fund_sub_agent_wallet_usecase.dart';
import '../../domain/usecases/get_pending_approval_requests_usecase.dart';
import '../../domain/usecases/get_sub_agents_usecase.dart';
import '../../domain/usecases/reject_sub_agent_request_usecase.dart';
import 'agents_event.dart';
import 'agents_state.dart';

class AgentsBloc extends Bloc<AgentsEvent, AgentsState> {
  AgentsBloc({
    required GetSubAgentsUseCase getSubAgentsUseCase,
    required GetPendingApprovalRequestsUseCase getPendingApprovalRequestsUseCase,
    required ApproveSubAgentRequestUseCase approveSubAgentRequestUseCase,
    required RejectSubAgentRequestUseCase rejectSubAgentRequestUseCase,
    required FundSubAgentWalletUseCase fundSubAgentWalletUseCase,
    required GetWalletBalanceUseCase getWalletBalanceUseCase,
  })  : _getSubAgentsUseCase = getSubAgentsUseCase,
        _getPendingApprovalRequestsUseCase = getPendingApprovalRequestsUseCase,
        _approveSubAgentRequestUseCase = approveSubAgentRequestUseCase,
        _rejectSubAgentRequestUseCase = rejectSubAgentRequestUseCase,
        _fundSubAgentWalletUseCase = fundSubAgentWalletUseCase,
        _getWalletBalanceUseCase = getWalletBalanceUseCase,
        super(const AgentsInitial()) {
    on<AgentsLoadRequested>(_onLoadRequested, transformer: droppable());
    on<SubAgentRequestApproveSubmitted>(_onApproveSubmitted, transformer: droppable());
    on<SubAgentRequestRejectSubmitted>(_onRejectSubmitted, transformer: droppable());
    on<ApprovalStatusCleared>(_onApprovalStatusCleared);
    on<SubAgentWalletFundingSubmitted>(_onFundingSubmitted, transformer: droppable());
    on<FundingStatusCleared>(_onFundingStatusCleared);
  }

  final GetSubAgentsUseCase _getSubAgentsUseCase;
  final GetPendingApprovalRequestsUseCase _getPendingApprovalRequestsUseCase;
  final ApproveSubAgentRequestUseCase _approveSubAgentRequestUseCase;
  final RejectSubAgentRequestUseCase _rejectSubAgentRequestUseCase;
  final FundSubAgentWalletUseCase _fundSubAgentWalletUseCase;
  final GetWalletBalanceUseCase _getWalletBalanceUseCase;

  Future<void> _onLoadRequested(
    AgentsLoadRequested event,
    Emitter<AgentsState> emit,
  ) async {
    emit(const AgentsLoading());

    final subAgentsResult = await _getSubAgentsUseCase();
    if (subAgentsResult case Left(:final value)) {
      emit(AgentsFailure(value.message));
      return;
    }
    final pendingResult = await _getPendingApprovalRequestsUseCase();
    if (pendingResult case Left(:final value)) {
      emit(AgentsFailure(value.message));
      return;
    }

    final subAgents = (subAgentsResult as Right<Failure, List<SubAgent>>).value;
    final pending =
        (pendingResult as Right<Failure, List<SubAgentRequestSummary>>).value;

    emit(
      AgentsLoaded(
        subAgents: subAgents,
        pendingRequests: pending,
        masterWalletBalanceLoading: true,
      ),
    );

    final balanceResult = await _getWalletBalanceUseCase();
    final current = state;
    if (current is! AgentsLoaded) return; // Reset/navigated away meanwhile.
    emit(
      balanceResult.match(
        (failure) => current.copyWith(masterWalletBalanceLoading: false),
        (balance) => current.copyWith(
          masterWalletBalance: balance,
          masterWalletBalanceLoading: false,
        ),
      ),
    );
  }

  Future<void> _onApproveSubmitted(
    SubAgentRequestApproveSubmitted event,
    Emitter<AgentsState> emit,
  ) async {
    final current = state;
    if (current is! AgentsLoaded) return;

    emit(
      current.copyWith(
        approvalActionStatus: ApprovalActionStatus.submitting,
        approvalActionKind: ApprovalActionKind.approve,
        approvalActionRequestId: event.requestId,
        clearApprovalActionError: true,
      ),
    );

    final result = await _approveSubAgentRequestUseCase(event.requestId);
    final latest = state;
    if (latest is! AgentsLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          approvalActionStatus: ApprovalActionStatus.failure,
          approvalActionError: failure.message,
        ),
        (_) => latest
            .copyWith(
              pendingRequests: latest.pendingRequests
                  .where((r) => r.id != event.requestId)
                  .toList(),
              approvalActionStatus: ApprovalActionStatus.success,
            ),
      ),
    );
  }

  Future<void> _onRejectSubmitted(
    SubAgentRequestRejectSubmitted event,
    Emitter<AgentsState> emit,
  ) async {
    final current = state;
    if (current is! AgentsLoaded) return;

    emit(
      current.copyWith(
        approvalActionStatus: ApprovalActionStatus.submitting,
        approvalActionKind: ApprovalActionKind.reject,
        approvalActionRequestId: event.requestId,
        clearApprovalActionError: true,
      ),
    );

    final result = await _rejectSubAgentRequestUseCase(
      event.requestId,
      reason: event.reason,
    );
    final latest = state;
    if (latest is! AgentsLoaded) return;
    emit(
      result.match(
        (failure) => latest.copyWith(
          approvalActionStatus: ApprovalActionStatus.failure,
          approvalActionError: failure.message,
        ),
        (_) => latest.copyWith(
          pendingRequests:
              latest.pendingRequests.where((r) => r.id != event.requestId).toList(),
          approvalActionStatus: ApprovalActionStatus.success,
        ),
      ),
    );
  }

  void _onApprovalStatusCleared(
    ApprovalStatusCleared event,
    Emitter<AgentsState> emit,
  ) {
    final current = state;
    if (current is! AgentsLoaded) return;
    emit(
      current.copyWith(
        approvalActionStatus: ApprovalActionStatus.idle,
        clearApprovalActionRequestId: true,
        clearApprovalActionError: true,
      ),
    );
  }

  Future<void> _onFundingSubmitted(
    SubAgentWalletFundingSubmitted event,
    Emitter<AgentsState> emit,
  ) async {
    final current = state;
    if (current is! AgentsLoaded) return;

    emit(
      current.copyWith(
        fundingStatus: FundingStatus.submitting,
        fundingSubAgentId: event.subAgentId,
        clearFundingError: true,
      ),
    );

    final result = await _fundSubAgentWalletUseCase(
      subAgentId: event.subAgentId,
      amountCents: event.amountCents,
      note: event.note,
    );
    final latest = state;
    if (latest is! AgentsLoaded) return;

    if (result case Left(:final value)) {
      emit(
        latest.copyWith(
          fundingStatus: FundingStatus.failure,
          fundingError: value.message,
        ),
      );
      return;
    }
    final updatedSubAgent = (result as Right<Failure, SubAgent>).value;

    // Success: the master agent's wallet balance decreased server-side —
    // refetch it rather than fabricate the new figure client-side (same
    // rule as Wallet's top-up flow).
    final balanceResult = await _getWalletBalanceUseCase();
    final afterFund = state;
    if (afterFund is! AgentsLoaded) return;
    emit(
      afterFund.copyWith(
        subAgents: [
          for (final subAgent in afterFund.subAgents)
            if (subAgent.id == updatedSubAgent.id) updatedSubAgent else subAgent,
        ],
        masterWalletBalance: balanceResult.match(
          (_) => afterFund.masterWalletBalance,
          (balance) => balance,
        ),
        fundingStatus: FundingStatus.success,
      ),
    );
  }

  void _onFundingStatusCleared(
    FundingStatusCleared event,
    Emitter<AgentsState> emit,
  ) {
    final current = state;
    if (current is! AgentsLoaded) return;
    emit(
      current.copyWith(
        fundingStatus: FundingStatus.idle,
        clearFundingSubAgentId: true,
        clearFundingError: true,
      ),
    );
  }
}
