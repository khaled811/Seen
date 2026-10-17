// Agent profile (Figma AGT-04) and suspend / reactivate (AGT-03): the bloc and
// the screen over fake repositories. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_profile.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_request_summary.dart';
import 'package:seen_booking/features/agents/domain/repositories/agents_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/approve_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/fund_sub_agent_wallet_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_pending_approval_requests_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_sub_agents_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/reject_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/sub_agent_management_usecases.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agent_profile_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_event.dart';
import 'package:seen_booking/features/agents/presentation/screens/agent_profile_screen.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

class _World {
  bool active = true;
  Either<Failure, SubAgentProfile>? profileOverride;
  Either<Failure, SubAgent>? activeOverride;
  String? lastReason;
  int setActiveCalls = 0;
  int profileLoads = 0;

  SubAgent get agent => SubAgent(
        id: '1',
        name: 'مكتب الريان للسفر',
        code: 'AG-101',
        balanceCents: 42000,
        isActive: active,
        creditLimitCents: 50000,
        creditUsedCents: 38000,
      );

  SubAgentProfile get profile => SubAgentProfile(
        agent: agent,
        city: 'عدن',
        memberSince: DateTime(2024, 3, 1),
        monthlyRequestCount: 412,
        inProgressRequestCount: 3,
        ledger: [
          AgentLedgerEntry(
              id: 'l1',
              title: 'تمويل من الوكيل الرئيسي',
              amountCents: 30000,
              isCredit: true,
              createdAt: DateTime(2026, 10, 1)),
          AgentLedgerEntry(
              id: 'l2',
              title: 'SB-20484 · حجز طيران',
              amountCents: 124000,
              isCredit: false,
              createdAt: DateTime(2026, 9, 30)),
        ],
        requests: [
          AgentRequestRow(
            id: 'r1',
            referenceId: 'SB-20488',
            serviceName: 'تأشيرة السعودية',
            status: RequestStatus.processing,
            submittedAt: DateTime(2026, 10, 1),
          ),
        ],
      );
}

class _Repo implements AgentsRepository {
  _Repo(this.w);
  final _World w;

  @override
  Future<Either<Failure, SubAgentProfile>> getSubAgentProfile(
      String subAgentId) async {
    w.profileLoads++;
    return w.profileOverride ?? Right(w.profile);
  }

  @override
  Future<Either<Failure, SubAgent>> setSubAgentActive({
    required String subAgentId,
    required bool active,
    String? reason,
  }) async {
    w.setActiveCalls++;
    w.lastReason = reason;
    if (w.activeOverride != null) return w.activeOverride!;
    w.active = active;
    return Right(w.agent);
  }

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async =>
      Right([w.agent]);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>>
      getPendingApprovalRequests() async => const Right([]);

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId,
          {required String reason}) async =>
      const Right(null);

  @override
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    String? note,
  }) async =>
      Right(w.agent);

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(
          NewSubAgent newSubAgent) async =>
      Right(w.agent);

  @override
  Future<Either<Failure, SubAgent>> updateCreditLimit(
          {required String subAgentId, required int limitCents}) async =>
      Right(w.agent);
}

class _WalletRepo implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(
            availableCents: 132200,
            holdCents: 0,
            creditLimitCents: 0,
            currency: WalletCurrency.usd),
      );

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async =>
      throw UnimplementedError();
}

AgentProfileBloc _profileBloc(_World w) => AgentProfileBloc(
      getProfile: GetSubAgentProfileUseCase(_Repo(w)),
      setActive: SetSubAgentActiveUseCase(_Repo(w)),
    );

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('AgentProfileBloc', () {
    test(
        'loads the profile; a failed first load reports failed, with offline flagged',
        () async {
      final w = _World()..profileOverride = const Left(NetworkFailure('x'));
      final bloc = _profileBloc(w);
      addTearDown(bloc.close);
      bloc.add(const AgentProfileLoadRequested('1'));
      final failed = await bloc.stream
          .firstWhere((s) => s.status == AgentProfileStatus.failed);
      expect(failed.offline, true);

      w.profileOverride = null;
      bloc.add(const AgentProfileLoadRequested('1'));
      final ok = await bloc.stream
          .firstWhere((s) => s.status == AgentProfileStatus.ready);
      expect(ok.profile!.agent.name, 'مكتب الريان للسفر');
    });

    test(
        'suspend keeps the profile and flips the status; failure keeps it unchanged',
        () async {
      final w = _World();
      final bloc = _profileBloc(w);
      addTearDown(bloc.close);
      bloc.add(const AgentProfileLoadRequested('1'));
      await bloc.stream.firstWhere((s) => s.status == AgentProfileStatus.ready);

      bloc.add(const AgentActiveChangeSubmitted(
          active: false, reason: 'تجاوز الحد'));
      var s = await bloc.stream
          .firstWhere((s) => s.outcome == AgentProfileOutcome.suspended);
      expect(s.profile!.agent.isActive, false);
      expect(s.profile!.ledger, isNotEmpty);
      expect(w.lastReason, 'تجاوز الحد');

      w.activeOverride = const Left(ServerFailure('x'));
      bloc.add(const AgentActiveChangeSubmitted(active: true));
      s = await bloc.stream
          .firstWhere((s) => s.outcome == AgentProfileOutcome.failed);
      expect(s.profile!.agent.isActive, false);
      expect(s.busy, false);
    });
  });

  group('AgentProfileScreen', () {
    late _World w;

    Future<void> open(WidgetTester tester) async {
      w = _World();
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final agents = _Repo(w);
      final agentsBloc = AgentsBloc(
        getSubAgentsUseCase: GetSubAgentsUseCase(agents),
        getPendingApprovalRequestsUseCase:
            GetPendingApprovalRequestsUseCase(agents),
        approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(agents),
        rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(agents),
        fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(agents),
        getWalletBalanceUseCase: GetWalletBalanceUseCase(_WalletRepo()),
      )..add(const AgentsLoadRequested());
      addTearDown(() => agentsBloc.close().ignore());
      await tester.pumpWidget(BlocProvider.value(
        value: agentsBloc,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          home: AgentProfileScreen(
              subAgent: w.agent, createBloc: () => _profileBloc(w)),
        ),
      ));
      await settle(tester);
    }

    testWidgets(
        'shows the card, the three figures, the actions, the ledger and the requests',
        (tester) async {
      await open(tester);
      expect(find.text('مكتب الريان للسفر'), findsOneWidget);
      expect(find.textContaining('عدن · وكيل فرعي منذ مارس'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
      expect(find.textContaining('420.00'), findsOneWidget);
      expect(find.textContaining('500.00'), findsOneWidget);
      expect(find.text('٤١٢'), findsOneWidget);
      for (final a in ['إيقاف', 'تعديل الحد', 'تمويل']) {
        expect(find.text(a), findsOneWidget);
      }
      expect(find.text('سجل الرصيد'), findsOneWidget);
      expect(find.text('تمويل من الوكيل الرئيسي'), findsOneWidget);
      expect(find.text('+300.00'), findsOneWidget);
      expect(find.text('−1,240.00'), findsOneWidget);
      expect(find.text('طلبات الوكيل · ٣ قيد التنفيذ'), findsOneWidget);
      expect(find.text('تأشيرة السعودية'), findsOneWidget);
    });

    testWidgets(
        'suspend needs a reason, names the requests in progress, then flips to Reactivate',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('إيقاف'));
      await tester.pumpAndSettle();
      expect(find.text('إيقاف الوكيل؟'), findsOneWidget);
      expect(find.textContaining('٣ طلبات قيد التنفيذ'), findsWidgets);

      // Without a reason nothing is sent.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.text('إيقاف')));
      await tester.pumpAndSettle();
      expect(w.setActiveCalls, 0);
      expect(find.text('إيقاف الوكيل؟'), findsOneWidget);

      await tester.enterText(
          find.descendant(
              of: find.byType(Dialog), matching: find.byType(TextFormField)),
          'تجاوز حد الائتمان المتكرر');
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.text('إيقاف')));
      await settle(tester);
      expect(w.setActiveCalls, 1);
      expect(w.lastReason, 'تجاوز حد الائتمان المتكرر');
      expect(find.text('موقوف'), findsOneWidget);
      expect(find.text('إعادة التفعيل'), findsOneWidget);
    });

    testWidgets('reactivate asks without a reason and sends active = true',
        (tester) async {
      await open(tester);
      w.active = false;
      // Reload so the screen shows the suspended state.
      final ctx = tester.element(find.byType(Scaffold).first);
      ctx.read<AgentProfileBloc>().add(const AgentProfileLoadRequested('1'));
      await settle(tester);
      await tester.tap(find.text('إعادة التفعيل'));
      await tester.pumpAndSettle();
      expect(find.text('إعادة تفعيل الوكيل؟'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.text('إعادة التفعيل')));
      await settle(tester);
      expect(w.setActiveCalls, 1);
      expect(w.active, true);
    });
  });
}
