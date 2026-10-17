// Sub-agents screen (Figma 13): overview tiles, segmented filter, header search
// and the card list, driven by a real AgentsBloc over fake repositories.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
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
import 'package:seen_booking/features/agents/presentation/screens/sub_agents_list_screen.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

const _agents = [
  SubAgent(id: '1', name: 'مكتب الريان', code: 'AG-101', balanceCents: 42000, isActive: true),
  SubAgent(id: '2', name: 'النخبة للسياحة', code: 'AG-102', balanceCents: 9650, isActive: true),
  SubAgent(id: '3', name: 'سما المكلا', code: 'AG-103', balanceCents: 0, isActive: false),
];

class _AgentsRepo implements AgentsRepository {
  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async => const Right(_agents);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests() async => const Right([]);

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async => const Right(null);

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason}) async =>
      const Right(null);

  @override
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({required String subAgentId, required int amountCents, String? note}) async =>
      const Right(SubAgent(id: '1', name: 'x', code: 'x', balanceCents: 0, isActive: true));
}

class _WalletRepo implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(availableCents: 100000, holdCents: 0, creditLimitCents: 0, currency: WalletCurrency.usd),
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

void main() {
  late AgentsBloc bloc;

  setUp(() {
    final agents = _AgentsRepo();
    bloc = AgentsBloc(
      getSubAgentsUseCase: GetSubAgentsUseCase(agents),
      getPendingApprovalRequestsUseCase: GetPendingApprovalRequestsUseCase(agents),
      approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(agents),
      rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(agents),
      fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(agents),
      getWalletBalanceUseCase: GetWalletBalanceUseCase(_WalletRepo()),
    )..add(const AgentsLoadRequested());
  });

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => bloc.close().ignore());
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BlocProvider<AgentsBloc>.value(
      value: bloc,
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
        home: const SubAgentsView(),
      ),
    ));
    await tester.runAsync(() async {
      while (bloc.state is! AgentsLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();
  }

  testWidgets('shows the overview tiles and every agent card', (tester) async {
    await open(tester);
    expect(find.text('الوكلاء'), findsOneWidget);
    expect(find.text('٢'), findsOneWidget); // two active agents
    expect(find.textContaining('516.50'), findsOneWidget); // total of all balances
    for (final n in ['مكتب الريان', 'النخبة للسياحة', 'سما المكلا']) {
      expect(find.text(n), findsOneWidget);
    }
  });

  testWidgets('the suspended segment keeps only suspended agents', (tester) async {
    await open(tester);
    await tester.tap(find.text('موقوف').first);
    await tester.pump();
    expect(find.text('سما المكلا'), findsOneWidget);
    expect(find.text('مكتب الريان'), findsNothing);
  });

  testWidgets('the header search button reveals a field that filters by name', (tester) async {
    await open(tester);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.bySemanticsLabel('بحث'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'النخبة');
    await tester.pump();
    expect(find.text('النخبة للسياحة'), findsOneWidget);
    expect(find.text('مكتب الريان'), findsNothing);

    await tester.tap(find.bySemanticsLabel('بحث'));
    await tester.pump();
    expect(find.text('مكتب الريان'), findsOneWidget); // closing clears the query
  });

  testWidgets('the add-agent FAB explains it is not available yet', (tester) async {
    await open(tester);
    await tester.tap(find.text('إضافة وكيل'));
    await tester.pump();
    expect(find.text('إضافة وكيل جديد غير متاحة بعد.'), findsOneWidget);
  });
}
