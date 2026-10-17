// Transfer to agent (Figma WAL-07 / 07b / 07c): choose, amount, confirm sheet,
// success page, over a real AgentsBloc with fake repositories. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
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
import 'package:seen_booking/features/agents/presentation/screens/transfer_to_agent_screen.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

class _World {
  int masterCents = 132200;
  int agentCents = 42000;
  Either<Failure, SubAgent>? fundOverride;
  int? lastAmount;
  String? lastNote;
  int funds = 0;
}

class _AgentsRepo implements AgentsRepository {
  _AgentsRepo(this.w);
  final _World w;

  List<SubAgent> get _agents => [
        SubAgent(id: '1', name: 'مكتب الريان للسفر', code: 'AG-101', balanceCents: w.agentCents, isActive: true),
        const SubAgent(id: '2', name: 'النخبة للسياحة', code: 'AG-102', balanceCents: 9650, isActive: true),
        const SubAgent(id: '3', name: 'سما المكلا', code: 'AG-103', balanceCents: 0, isActive: false),
      ];

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async => Right(_agents);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests() async => const Right([]);

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async => const Right(null);

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason}) async => const Right(null);

  @override
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    String? note,
  }) async {
    w.funds++;
    w.lastAmount = amountCents;
    w.lastNote = note;
    if (w.fundOverride != null) return w.fundOverride!;
    w.masterCents -= amountCents;
    w.agentCents += amountCents;
    return Right(_agents.first);
  }

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent newSubAgent) async =>
      const Right(SubAgent(id: 'new', name: 'x', code: 'x', balanceCents: 0, isActive: true));

  @override
  Future<Either<Failure, SubAgent>> updateCreditLimit({required String subAgentId, required int limitCents}) async =>
      const Right(SubAgent(id: 'x', name: 'x', code: 'x', balanceCents: 0, isActive: true));
}

class _WalletRepo implements WalletRepository {
  _WalletRepo(this.w);
  final _World w;

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => Right(
        WalletBalance(availableCents: w.masterCents, holdCents: 0, creditLimitCents: 0, currency: WalletCurrency.usd),
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
  late _World w;
  var popped = false;

  Future<void> open(WidgetTester tester) async {
    w = _World();
    popped = false;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final agents = _AgentsRepo(w);
    final wallet = _WalletRepo(w);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => TransferToAgentScreen(
                  createBloc: () => AgentsBloc(
                    getSubAgentsUseCase: GetSubAgentsUseCase(agents),
                    getPendingApprovalRequestsUseCase: GetPendingApprovalRequestsUseCase(agents),
                    approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(agents),
                    rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(agents),
                    fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(agents),
                    getWalletBalanceUseCase: GetWalletBalanceUseCase(wallet),
                  ),
                ),
              ));
              popped = r == true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester);
  }

  testWidgets('choose an agent, amount and note, confirm, success shows the refetched balance', (tester) async {
    await open(tester);
    expect(find.text('اختر الوكيل'), findsOneWidget);
    expect(find.textContaining('1,322.00'), findsOneWidget);

    await tester.tap(find.text('اختر الوكيل'));
    await settle(tester);
    expect(find.text('سما المكلا'), findsNothing); // inactive agents are not offered
    await tester.tap(find.text('مكتب الريان للسفر'));
    await settle(tester);
    expect(find.text('تغيير'), findsOneWidget);

    await tester.tap(find.text('300'));
    await tester.pump();
    expect(find.text('300.00'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'تمويل طلبات العمرة');
    await tester.pump();

    await tester.tap(find.text('مراجعة التحويل'));
    await settle(tester);
    expect(find.text('تأكيد التحويل'), findsNWidgets(2)); // title + button
    expect(find.textContaining('1,022.00'), findsOneWidget); // my balance after
    expect(find.textContaining('720.00'), findsOneWidget); // agent balance after

    await tester.tap(find.widgetWithText(SeenButton, 'تأكيد التحويل'));
    await settle(tester);
    expect(w.funds, 1);
    expect(w.lastAmount, 30000);
    expect(w.lastNote, 'تمويل طلبات العمرة');
    expect(find.text('تم التحويل'), findsOneWidget);
    expect(find.textContaining('1,022.00'), findsOneWidget); // refetched balance

    await tester.tap(find.text('العودة للمحفظة'));
    await settle(tester);
    expect(popped, isTrue);
  });

  testWidgets('an amount above the balance shows the red banner and blocks the review', (tester) async {
    await open(tester);
    await tester.tap(find.text('اختر الوكيل'));
    await settle(tester);
    await tester.tap(find.text('مكتب الريان للسفر'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '1500');
    await tester.pump();
    expect(find.textContaining('الرصيد غير كافٍ'), findsOneWidget);

    await tester.tap(find.text('مراجعة التحويل'));
    await settle(tester);
    expect(find.text('تأكيد التحويل'), findsNothing);
    expect(w.funds, 0);
  });

  testWidgets('a failed transfer keeps the sheet open and sends nothing twice', (tester) async {
    await open(tester);
    await tester.tap(find.text('اختر الوكيل'));
    await settle(tester);
    await tester.tap(find.text('مكتب الريان للسفر'));
    await settle(tester);
    await tester.tap(find.text('100'));
    await tester.pump();
    await tester.tap(find.text('مراجعة التحويل'));
    await settle(tester);
    w.fundOverride = const Left(ServerFailure('فشل التحويل'));
    await tester.tap(find.widgetWithText(SeenButton, 'تأكيد التحويل'));
    await settle(tester);
    expect(find.text('فشل التحويل'), findsOneWidget);
    expect(find.text('تم التحويل'), findsNothing);
    expect(w.funds, 1);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
