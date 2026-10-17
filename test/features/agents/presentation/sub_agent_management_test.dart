// Add sub-agent (Figma AGT-01 / 01b) and edit credit limit (AGT-02): issue
// mapping, blocs over a fake repository, and the screen / sheet. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_request_summary.dart';
import 'package:seen_booking/features/agents/domain/repositories/agents_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/sub_agent_management_usecases.dart';
import 'package:seen_booking/features/agents/presentation/bloc/sub_agent_management_bloc.dart';
import 'package:seen_booking/features/agents/presentation/screens/add_sub_agent_screen.dart';
import 'package:seen_booking/features/agents/presentation/widgets/edit_credit_limit_sheet.dart';

const _rayan = SubAgent(
  id: '1',
  name: 'مكتب الريان للسفر',
  code: 'AG-101',
  balanceCents: 42000,
  isActive: true,
  creditLimitCents: 50000,
  creditUsedCents: 38000,
);

class _Repo implements AgentsRepository {
  Either<Failure, SubAgent>? createResult;
  Either<Failure, SubAgent>? updateResult;
  NewSubAgent? lastNew;
  int? lastLimit;
  int creates = 0;
  int updates = 0;

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent n) async {
    creates++;
    lastNew = n;
    return createResult ??
        Right(SubAgent(
            id: 'n',
            name: n.agencyName,
            code: 'NEW-01',
            balanceCents: 0,
            isActive: !n.sendInvite,
            invitePending: n.sendInvite));
  }

  @override
  Future<Either<Failure, SubAgent>> updateCreditLimit(
      {required String subAgentId, required int limitCents}) async {
    updates++;
    lastLimit = limitCents;
    return updateResult ?? const Right(_rayan);
  }

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async =>
      const Right([]);

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
      const Right(_rayan);
}

const _newAgent = NewSubAgent(
    agencyName: 'مكتب الريان', managerName: 'وليد', phone: '+967771234567');

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('SubAgentIssue.from maps codes and details', () {
    expect(SubAgentIssue.from(const NetworkFailure('x')).kind,
        SubAgentIssueKind.offline);
    expect(
      SubAgentIssue.from(
              const ServerFailure('x', code: SubAgentIssue.phoneTakenCode))
          .kind,
      SubAgentIssueKind.phoneTaken,
    );
    final below = SubAgentIssue.from(
      const ServerFailure('x',
          code: SubAgentIssue.limitBelowUsageCode,
          details: {'usedCents': 38000}),
    );
    expect((below.kind, below.amountCents),
        (SubAgentIssueKind.limitBelowUsage, 38000));
    expect(SubAgentIssue.from(const ServerFailure('boom')).kind,
        SubAgentIssueKind.generic);
  });

  group('blocs', () {
    test('AddSubAgentBloc: success, then reset', () async {
      final repo = _Repo();
      final bloc = AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo));
      addTearDown(bloc.close);
      bloc.add(const AddSubAgentSubmitted(_newAgent));
      final s = await bloc.stream.firstWhere((s) => s.created != null);
      expect(s.created!.invitePending, true);
      bloc.add(const AddSubAgentReset());
      await bloc.stream.firstWhere((s) => s.created == null);
    });

    test('AddSubAgentBloc: a taken phone is reported and dismissible',
        () async {
      final repo = _Repo()
        ..createResult =
            const Left(ServerFailure('x', code: SubAgentIssue.phoneTakenCode));
      final bloc = AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo));
      addTearDown(bloc.close);
      bloc.add(const AddSubAgentSubmitted(_newAgent));
      final s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.kind, SubAgentIssueKind.phoneTaken);
      bloc.add(const AddSubAgentIssueDismissed());
      await bloc.stream.firstWhere((s) => s.issue == null);
    });

    test('CreditLimitBloc: below usage comes back as an issue with the usage',
        () async {
      final repo = _Repo()
        ..updateResult = const Left(
          ServerFailure('x',
              code: SubAgentIssue.limitBelowUsageCode,
              details: {'usedCents': 38000}),
        );
      final bloc =
          CreditLimitBloc(updateCreditLimit: UpdateCreditLimitUseCase(repo));
      addTearDown(bloc.close);
      bloc.add(const CreditLimitSubmitted(subAgentId: '1', limitCents: 30000));
      final s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.amountCents, 38000);
    });
  });

  group('AddSubAgentScreen', () {
    late _Repo repo;

    Future<void> open(WidgetTester tester) async {
      repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
            builder: (_) => AddSubAgentScreen(
              createBloc: () =>
                  AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo)),
            ),
          )),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester) async {
      final f = find.byType(TextFormField);
      await tester.enterText(f.at(0), 'مكتب الريان للسفر');
      await tester.pump();
      await tester.enterText(f.at(1), 'وليد ناصر الريان');
      await tester.pump();
      await tester.enterText(f.at(2), '771234567');
      await tester.pump();
      await tester.enterText(f.at(4), '500');
      await tester.pump();
      await tester.enterText(f.at(5), '10');
      await tester.pump();
    }

    testWidgets('an empty form shows the required errors and sends nothing',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await tester.pump();
      expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
      expect(repo.creates, 0);
    });

    testWidgets(
        'a valid form sends the agent with the invite and shows the success page',
        (tester) async {
      await open(tester);
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      expect(repo.lastNew!.phone, '+967771234567');
      expect(repo.lastNew!.marginPercent, 10);
      expect(repo.lastNew!.creditLimitCents, 50000);
      expect(repo.lastNew!.sendInvite, true);
      expect(find.text('أُضيف الوكيل'), findsOneWidget);
      expect(find.text('قيد التفعيل'), findsOneWidget);

      await tester.tap(find.text('إضافة آخر'));
      await settle(tester);
      expect(find.text('إضافة الوكيل'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          isEmpty);
    });

    testWidgets('a taken phone shows the red message under the field',
        (tester) async {
      await open(tester);
      repo.createResult =
          const Left(ServerFailure('x', code: SubAgentIssue.phoneTakenCode));
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      expect(find.text('هذا الرقم مسجّل لوكيل آخر. استخدم رقمًا مختلفًا.'),
          findsOneWidget);
      expect(find.text('أُضيف الوكيل'), findsNothing);
    });

    testWidgets('back to the agents leaves with true so the list reloads',
        (tester) async {
      await open(tester);
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      await tester.tap(find.text('العودة إلى الوكلاء'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('EditCreditLimitSheet', () {
    late _Repo repo;

    Future<bool?> open(WidgetTester tester, {int? max = 132200}) async {
      repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool? result;
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showEditCreditLimitSheet(
                context,
                subAgent: _rayan,
                masterAvailableCents: max,
                createBloc: () => CreditLimitBloc(
                    updateCreditLimit: UpdateCreditLimitUseCase(repo)),
              );
            },
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets(
        'shows the current limit and usage; below usage blocks saving with the message',
        (tester) async {
      await open(tester);
      expect(find.textContaining('500.00'), findsWidgets);
      expect(find.textContaining('380.00'), findsOneWidget);
      expect(find.textContaining('1,322.00'), findsOneWidget); // standing hint

      await tester.enterText(find.byType(TextFormField), '300');
      await tester.pump();
      expect(find.textContaining('أقل من المستخدم حاليًا'), findsOneWidget);
      expect(
          tester
              .widget<SeenButton>(find.widgetWithText(SeenButton, 'حفظ الحد'))
              .onPressed,
          isNull);
    });

    testWidgets(
        'above the main balance is blocked; a valid new limit saves and closes',
        (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), '2000');
      await tester.pump();
      expect(
          find.textContaining('أكبر من رصيدك الرئيسي المتاح'), findsOneWidget);
      expect(
          tester
              .widget<SeenButton>(find.widgetWithText(SeenButton, 'حفظ الحد'))
              .onPressed,
          isNull);

      await tester.enterText(find.byType(TextFormField), '800');
      await tester.pump();
      await tester.tap(find.widgetWithText(SeenButton, 'حفظ الحد'));
      await settle(tester);
      expect(repo.lastLimit, 80000);
      expect(find.text('تعديل حد الائتمان'), findsNothing); // sheet closed
    });
  });
}
