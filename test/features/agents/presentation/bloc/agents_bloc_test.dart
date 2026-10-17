import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_request_summary.dart';
import 'package:seen_booking/features/agents/domain/repositories/agents_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/approve_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/fund_sub_agent_wallet_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_pending_approval_requests_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_sub_agents_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/reject_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_event.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_state.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

const _subAgent1 = SubAgent(
  id: 'sub-1',
  name: 'Cairo Branch',
  code: 'CAI-01',
  balanceCents: 100000,
  isActive: true,
  marginPercent: 3.0,
);
const _subAgent2 = SubAgent(
  id: 'sub-2',
  name: 'Alexandria Branch',
  code: 'ALX-02',
  balanceCents: 50000,
  isActive: true,
);

SubAgentRequestSummary _pendingRequest(String id) => SubAgentRequestSummary(
      id: id,
      referenceId: 'SB-$id',
      subAgentName: 'Cairo Branch',
      serviceName: 'Egypt National Security Approval',
      travelerCount: 1,
      totalPriceCents: 15000,
      submittedAt: DateTime(2026, 1, 1),
    );

const _masterBalance = WalletBalance(
  availableCents: 200000,
  holdCents: 0,
  creditLimitCents: 500000,
  currency: WalletCurrency.usd,
);

class _FakeAgentsRepository implements AgentsRepository {
  Either<Failure, List<SubAgent>> subAgentsResult = const Right([_subAgent1, _subAgent2]);
  Either<Failure, List<SubAgentRequestSummary>> pendingResult =
      Right([_pendingRequest('req-1'), _pendingRequest('req-2')]);
  Either<Failure, void> approveResult = const Right(null);
  Either<Failure, void> rejectResult = const Right(null);
  Either<Failure, SubAgent> fundResult = const Right(
    SubAgent(
      id: 'sub-1',
      name: 'Cairo Branch',
      code: 'CAI-01',
      balanceCents: 150000,
      isActive: true,
      marginPercent: 3.0,
    ),
  );

  String? lastRejectReason;

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async => subAgentsResult;

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests() async =>
      pendingResult;

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async => approveResult;

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason}) async {
    lastRejectReason = reason;
    return rejectResult;
  }

  @override
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    String? note,
  }) async =>
      fundResult;

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent newSubAgent) async =>
      const Right(SubAgent(id: 'new', name: 'x', code: 'x', balanceCents: 0, isActive: true));

  @override
  Future<Either<Failure, SubAgent>> updateCreditLimit({required String subAgentId, required int limitCents}) async =>
      const Right(SubAgent(id: 'x', name: 'x', code: 'x', balanceCents: 0, isActive: true));
}

class _FakeWalletRepository implements WalletRepository {
  Either<Failure, WalletBalance> balanceResult = const Right(_masterBalance);
  int getBalanceCalls = 0;

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async {
    getBalanceCalls++;
    return balanceResult;
  }

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw UnimplementedError('Not used by AgentsBloc');

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async =>
      throw UnimplementedError('Not used by AgentsBloc');
}

void main() {
  late _FakeAgentsRepository agentsRepository;
  late _FakeWalletRepository walletRepository;
  late AgentsBloc bloc;

  setUp(() {
    agentsRepository = _FakeAgentsRepository();
    walletRepository = _FakeWalletRepository();
    bloc = AgentsBloc(
      getSubAgentsUseCase: GetSubAgentsUseCase(agentsRepository),
      getPendingApprovalRequestsUseCase: GetPendingApprovalRequestsUseCase(agentsRepository),
      approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(agentsRepository),
      rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(agentsRepository),
      fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(agentsRepository),
      getWalletBalanceUseCase: GetWalletBalanceUseCase(walletRepository),
    );
  });

  tearDown(() => bloc.close());

  Future<AgentsLoaded> load() async {
    bloc.add(const AgentsLoadRequested());
    return await bloc.stream.firstWhere(
      (s) => s is AgentsLoaded && !s.masterWalletBalanceLoading,
    ) as AgentsLoaded;
  }

  test('initial state is AgentsInitial', () {
    expect(bloc.state, const AgentsInitial());
  });

  test('AgentsLoadRequested loads sub-agents, pending requests, and master balance', () async {
    final state = await load();
    expect(state.subAgents, hasLength(2));
    expect(state.pendingRequests, hasLength(2));
    expect(state.masterWalletBalance, _masterBalance);
  });

  group('approve flow', () {
    test('removes the approved request from pendingRequests on success', () async {
      await load();
      bloc.add(const SubAgentRequestApproveSubmitted('req-1'));

      await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.approvalActionStatus == ApprovalActionStatus.submitting,
      );
      final done = await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.approvalActionStatus == ApprovalActionStatus.success,
      ) as AgentsLoaded;

      expect(done.pendingRequests.map((r) => r.id), ['req-2']);
      expect(done.approvalActionKind, ApprovalActionKind.approve);
    });

    test('surfaces a failure without touching pendingRequests', () async {
      await load();
      agentsRepository.approveResult = const Left(ServerFailure('rejected by server'));

      bloc.add(const SubAgentRequestApproveSubmitted('req-1'));
      final failed = await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.approvalActionStatus == ApprovalActionStatus.failure,
      ) as AgentsLoaded;

      expect(failed.approvalActionError, 'rejected by server');
      expect(failed.pendingRequests, hasLength(2));
    });
  });

  group('reject flow', () {
    test('removes the rejected request and forwards the reason', () async {
      await load();
      bloc.add(
        const SubAgentRequestRejectSubmitted(requestId: 'req-2', reason: 'Missing documents'),
      );

      final done = await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.approvalActionStatus == ApprovalActionStatus.success,
      ) as AgentsLoaded;

      expect(done.pendingRequests.map((r) => r.id), ['req-1']);
      expect(done.approvalActionKind, ApprovalActionKind.reject);
      expect(agentsRepository.lastRejectReason, 'Missing documents');
    });
  });

  group('ApprovalStatusCleared', () {
    test('resets the approval status back to idle', () async {
      await load();
      bloc.add(const SubAgentRequestApproveSubmitted('req-1'));
      await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.approvalActionStatus == ApprovalActionStatus.success,
      );

      bloc.add(const ApprovalStatusCleared());
      final cleared = await bloc.stream.first as AgentsLoaded;
      expect(cleared.approvalActionStatus, ApprovalActionStatus.idle);
    });
  });

  group('wallet transfer (funding)', () {
    test('updates the sub-agent balance and refreshes the master balance on success', () async {
      await load();
      bloc.add(
        const SubAgentWalletFundingSubmitted(subAgentId: 'sub-1', amountCents: 50000),
      );

      await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.fundingStatus == FundingStatus.submitting,
      );
      final done = await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.fundingStatus == FundingStatus.success,
      ) as AgentsLoaded;

      final updated = done.subAgents.firstWhere((a) => a.id == 'sub-1');
      expect(updated.balanceCents, 150000);
      expect(walletRepository.getBalanceCalls, 2); // initial load + post-fund refresh
    });

    test('surfaces a repository failure (e.g. exceeds available balance)', () async {
      await load();
      agentsRepository.fundResult = const Left(
        ValidationFailure('Amount exceeds available balance.'),
      );

      bloc.add(
        const SubAgentWalletFundingSubmitted(subAgentId: 'sub-1', amountCents: 999999999),
      );
      final failed = await bloc.stream.firstWhere(
        (s) => s is AgentsLoaded && s.fundingStatus == FundingStatus.failure,
      ) as AgentsLoaded;

      expect(failed.fundingError, 'Amount exceeds available balance.');
      // The sub-agent list is untouched — no client-side balance fabrication.
      expect(failed.subAgents.firstWhere((a) => a.id == 'sub-1').balanceCents, 100000);
    });
  });
}
