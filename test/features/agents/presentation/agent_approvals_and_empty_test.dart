// Sub-agent approvals (Figma AGT-06 / 07), the agents empty states (AGT-08) and
// the fund sheet quick amounts (AGT-05). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import '../../../support/agents_fakes.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
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
import 'package:seen_booking/features/agents/presentation/bloc/agents_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_event.dart';
import 'package:seen_booking/features/agents/presentation/screens/sub_agent_approvals_screen.dart';
import 'package:seen_booking/features/agents/presentation/screens/sub_agents_list_screen.dart';
import 'package:seen_booking/features/agents/presentation/widgets/fund_sub_agent_sheet.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/entities/top_up_options.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

final _requests = [
  SubAgentRequestSummary(
    id: 'a',
    referenceId: 'SB-1',
    subAgentName: 'مكتب الريان',
    serviceName: 'حجز طيران',
    travelerCount: 4,
    totalPriceCents: 124000,
    submittedAt: DateTime(2026, 10, 1),
  ),
  SubAgentRequestSummary(
    id: 'b',
    referenceId: 'SB-2',
    subAgentName: 'النخبة للسياحة',
    serviceName: 'تأشيرة السعودية',
    travelerCount: 6,
    totalPriceCents: 90000,
    submittedAt: DateTime(2026, 10, 2),
  ),
];

class _World {
  List<SubAgent> agents = const [];
  List<SubAgentRequestSummary> pending = const [];
  String? approved;
  ({String id, String reason})? rejected;
  Either<Failure, void>? approveOverride;
  int? lastFund;
}

class _Repo implements AgentsRepository {
  _Repo(this.w);
  final _World w;

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async =>
      Right(w.agents);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>>
      getPendingApprovalRequests() async => Right(w.pending);

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async {
    if (w.approveOverride != null) return w.approveOverride!;
    w.approved = requestId;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId,
      {required String reason}) async {
    w.rejected = (id: requestId, reason: reason);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) async {
    w.lastFund = amountCents;
    final a = w.agents.first;
    final updated = SubAgent(
        id: a.id,
        name: a.name,
        code: a.code,
        balanceCents: a.balanceCents + amountCents,
        isActive: true);
    w.agents = [updated];
    return const Right(null);
  }

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(
          NewSubAgent newSubAgent) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, SubAgentProfile>> getSubAgentProfile(
          String subAgentId) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> setSubAgentActive({
    required String subAgentId,
    required bool active,
  }) async =>
      const Right(null);
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
  Future<Either<Failure, TopUpOptions>> getTopUpOptions() async => const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  }) async =>
      throw UnimplementedError();
}

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _World w;

  Future<AgentsBloc> pump(WidgetTester tester, Widget Function() home) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo(w);
    final bloc = AgentsBloc(
      getSubAgentsUseCase: GetSubAgentsUseCase(repo),
      getPendingApprovalRequestsUseCase:
          GetPendingApprovalRequestsUseCase(repo),
      approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(repo),
      rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(repo),
      fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(repo),
      getWalletBalanceUseCase: GetWalletBalanceUseCase(_WalletRepo()),
    )..add(const AgentsLoadRequested());
    addTearDown(() => bloc.close().ignore());
    await tester.pumpWidget(BlocProvider.value(
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
        home: home(),
      ),
    ));
    await settle(tester);
    return bloc;
  }

  setUp(() => w = _World());

  group('SubAgentApprovalsScreen', () {
    testWidgets(
        'lists the waiting requests with value and counts them in the header',
        (tester) async {
      w.pending = _requests;
      await pump(tester, () => const SubAgentApprovalsScreen(createTopUps: emptyTopUpsCubit));
      expect(find.text('موافقات الوكلاء'), findsOneWidget);
      expect(find.text('٢ بانتظارك'), findsOneWidget);
      expect(find.text('مكتب الريان'), findsOneWidget);
      expect(find.textContaining('حجز طيران · '), findsOneWidget);
      expect(find.textContaining('1,240.00'), findsOneWidget);
      expect(find.text('موافقة'), findsNWidgets(2));
    });

    testWidgets('approve removes the request', (tester) async {
      w.pending = _requests;
      await pump(tester, () => const SubAgentApprovalsScreen(createTopUps: emptyTopUpsCubit));
      await tester.tap(find.text('موافقة').first);
      await settle(tester);
      expect(w.approved, 'a');
      expect(find.text('مكتب الريان'), findsNothing);
      expect(find.text('النخبة للسياحة'), findsOneWidget);
    });

    testWidgets(
        'reject needs a reason; "another reason" needs a note; the reason is sent',
        (tester) async {
      w.pending = _requests;
      await pump(tester, () => const SubAgentApprovalsScreen(createTopUps: emptyTopUpsCubit));
      await tester.tap(find.text('رفض').first);
      await tester.pumpAndSettle();
      expect(find.text('سبب الرفض'), findsOneWidget);

      await tester.tap(find.text('رفض الطلب'));
      await tester.pumpAndSettle();
      expect(w.rejected, isNull); // nothing picked

      await tester.tap(find.text('سبب آخر'));
      await tester.pump();
      await tester.tap(find.text('رفض الطلب'));
      await tester.pumpAndSettle();
      expect(w.rejected, isNull); // "another" needs a note

      await tester.tap(find.text('القيمة تتجاوز الحد المتفق'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'قسّم الحجز');
      await tester.pump();
      await tester.tap(find.text('رفض الطلب'));
      await settle(tester);
      expect(w.rejected!.id, 'a');
      expect(w.rejected!.reason, 'القيمة تتجاوز الحد المتفق — قسّم الحجز');
      expect(find.text('مكتب الريان'), findsNothing);
    });

    testWidgets('nothing waiting shows the empty note', (tester) async {
      await pump(tester, () => const SubAgentApprovalsScreen(createTopUps: emptyTopUpsCubit));
      expect(find.text('لا طلبات بانتظار موافقتك'), findsOneWidget);
    });
  });

  group('agents list states', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
      InjectionContainer.instance.init();
    });

    testWidgets(
        'no agents at all: the empty state with an add button (and no tiles)',
        (tester) async {
      await pump(tester, () => const SubAgentsView());
      expect(find.text('لا يوجد وكلاء فرعيون بعد'), findsOneWidget);
      expect(find.text('إضافة وكيل فرعي'), findsOneWidget);
      expect(find.text('نشط'), findsNothing);
      await tester.tap(find.text('إضافة وكيل فرعي'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة الوكيل'), findsOneWidget); // the add form
    });

    testWidgets('empty suspended segment and a search without results',
        (tester) async {
      w.agents = const [
        SubAgent(
            id: '1',
            name: 'مكتب الريان',
            code: 'AG-1',
            balanceCents: 100,
            isActive: true)
      ];
      await pump(tester, () => const SubAgentsView());
      await tester.tap(find.text('موقوف').last);
      await tester.pump();
      expect(find.text('لا وكلاء موقوفون'), findsOneWidget);
      await tester.tap(find.text('جميع الأنواع'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('بحث'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'الصقر');
      await tester.pump();
      expect(find.text('لا وكيل باسم ‹الصقر›'), findsOneWidget);
    });

    testWidgets(
        'the approvals button shows the waiting count and opens the list',
        (tester) async {
      w.agents = const [
        SubAgent(
            id: '1',
            name: 'مكتب الريان',
            code: 'AG-1',
            balanceCents: 100,
            isActive: true)
      ];
      w.pending = _requests;
      await pump(tester, () => const SubAgentsView());
      expect(find.text('٢'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('موافقات الوكلاء')));
      await tester.pumpAndSettle();
      expect(find.text('٢ بانتظارك'), findsOneWidget);
    });
  });

  group('fund sheet (AGT-05)', () {
    testWidgets(
        'quick amounts fill the field and the success message carries the new balance',
        (tester) async {
      w.agents = const [
        SubAgent(
            id: '1',
            name: 'مكتب الريان',
            code: 'AG-1',
            balanceCents: 42000,
            isActive: true)
      ];
      await pump(
        tester,
        () => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFundSubAgentSheet(context,
                  subAgent: w.agents.first,
                  masterAvailableBalanceCents: 132200),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('تمويل الوكيل'), findsOneWidget);
      expect(find.textContaining('من رصيدك الرئيسي'), findsOneWidget);

      await tester.tap(find.text('500'));
      await tester.pump();
      expect(find.text('500.00'), findsOneWidget);
      await tester.tap(find.textContaining('تحويل'));
      await settle(tester);
      expect(w.lastFund, 50000);
      expect(find.textContaining('رصيد الوكيل الآن'), findsOneWidget);
      expect(find.textContaining('920.00'), findsOneWidget);
    });
  });
}
