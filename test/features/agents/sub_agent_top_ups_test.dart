// A sub-agency's funding requests, decided by its main agent: the documents against
// the contract, the cubit (one decision at a time, re-read after a lost connection),
// and the section on the approvals screen (money leaves the wallet: confirm first).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/data/datasources/sub_agent_top_up_remote_data_source.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_top_up.dart';
import 'package:seen_booking/features/agents/domain/repositories/sub_agent_top_up_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/sub_agent_top_up_usecases.dart';
import 'package:seen_booking/features/agents/presentation/bloc/sub_agent_top_ups_cubit.dart';
import 'package:seen_booking/features/agents/presentation/widgets/sub_agent_top_ups_section.dart';

import '../../support/agents_fakes.dart';
import '../../support/scripted_graphql_service.dart';

final _item = SubAgentTopUp(id: 't1', agentName: 'مكتب الريان', amountCents: 25000, createdAt: DateTime(2026, 10, 1), note: 'للأسبوع');
final _other = SubAgentTopUp(id: 't2', agentName: 'النخبة', amountCents: 10000, createdAt: DateTime(2026, 10, 2));

SubAgentTopUpsCubit _cubit(FakeSubAgentTopUpRepository repo) => SubAgentTopUpsCubit(SubAgentTopUpUseCases(repo));

class _Gated implements SubAgentTopUpRepository {
  final gate = Completer<void>();
  int approvals = 0;

  @override
  Future<Either<Failure, List<SubAgentTopUp>>> pending() async => Right([_item, _other]);

  @override
  Future<Either<Failure, void>> approve(String transactionId) async {
    approvals++;
    await gate.future;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> reject(String transactionId, {required String note}) async => const Right(null);
}

void main() {
  group('SubAgentTopUpRemoteDataSource', () {
    test('lists the pending requests of the sub-agencies', () async {
      final graphql = ScriptedGraphQLService({
        'PendingSubAgentTopUps': {
          'pendingSubAgentTopUps': [
            {'id': 't1', 'status': 'pending', 'amount': '250.00', 'note': 'x', 'createdAt': '2026-10-01T10:00:00+00:00', 'agent': {'name': 'الريان'}},
            {'id': 't2', 'status': 'approved', 'amount': '10.00', 'note': '', 'createdAt': '2026-10-01T10:00:00+00:00', 'agent': {'name': 'قديم'}},
          ],
        },
      });
      final list = ((await SubAgentTopUpRemoteDataSource(graphQLService: graphql).pending()) as Right).value as List<SubAgentTopUp>;
      expect(list.map((t) => (t.id, t.agentName, t.amountCents, t.note)), [('t1', 'الريان', 25000, 'x')]); // decided ones are not offered
    });

    test('approve and reject send the transaction id (and the note)', () async {
      final graphql = ScriptedGraphQLService({
        'ApproveSubAgentTopUp': {
          'approveSubAgentTopUp': {'id': 't1', 'status': 'approved'},
        },
        'RejectSubAgentTopUp': {
          'rejectSubAgentTopUp': {'id': 't2', 'status': 'rejected'},
        },
      });
      final source = SubAgentTopUpRemoteDataSource(graphQLService: graphql);
      expect((await source.approve('t1')).isRight(), isTrue);
      expect((await source.reject('t2', note: 'لا رصيد')).isRight(), isTrue);
      expect(graphql.where('ApproveSubAgentTopUp').single.variables, {'transactionId': 't1'});
      expect(graphql.where('RejectSubAgentTopUp').single.variables, {'transactionId': 't2', 'note': 'لا رصيد'});
    });

    test('a refusal keeps its code (for example not enough balance)', () async {
      final graphql = ScriptedGraphQLService({'ApproveSubAgentTopUp': const ServerFailure('x', code: 'insufficient_funds')});
      final failure = ((await SubAgentTopUpRemoteDataSource(graphQLService: graphql).approve('t1')) as Left).value as ServerFailure;
      expect(failure.code, 'insufficient_funds');
    });
  });

  group('SubAgentTopUpsCubit', () {
    test('loads the waiting requests; a failure is kept with its reason', () async {
      final repo = FakeSubAgentTopUpRepository([_item, _other]);
      final cubit = _cubit(repo);
      await cubit.load();
      expect(cubit.state.items.length, 2);

      repo.pendingFailure = const ServerFailure('x', code: 'permission_denied');
      await cubit.load();
      expect(cubit.state.load, TopUpsLoad.failure);
      expect(cubit.state.failure, isA<ServerFailure>());
      await cubit.close();
    });

    test('approving removes the request and says so once', () async {
      final repo = FakeSubAgentTopUpRepository([_item, _other]);
      final cubit = _cubit(repo);
      await cubit.load();
      await cubit.approve('t1');
      expect(repo.approved, ['t1']);
      expect(cubit.state.items.map((t) => t.id), ['t2']);
      expect((cubit.state.decision.kind, cubit.state.decision.seq), (TopUpDecisionKind.approved, 1));
      await cubit.close();
    });

    test('rejecting sends the note and removes the request', () async {
      final repo = FakeSubAgentTopUpRepository([_item]);
      final cubit = _cubit(repo);
      await cubit.load();
      await cubit.reject('t1', note: 'x');
      expect(repo.rejected.single, (id: 't1', note: 'x'));
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.decision.kind, TopUpDecisionKind.rejected);
      await cubit.close();
    });

    test('a refused decision keeps the request and reports why', () async {
      final repo = FakeSubAgentTopUpRepository([_item])..decisionFailure = const ServerFailure('x', code: 'insufficient_funds');
      final cubit = _cubit(repo);
      await cubit.load();
      await cubit.approve('t1');
      expect(cubit.state.items.length, 1);
      expect(cubit.state.decision.kind, TopUpDecisionKind.failed);
      expect((cubit.state.decision.failure as ServerFailure).code, 'insufficient_funds');
      expect(repo.pendingCalls, 1); // a clear answer: no need to read again
      await cubit.close();
    });

    test('a lost connection reads the list again: the decision may have gone through', () async {
      final repo = FakeSubAgentTopUpRepository([_item])..decisionFailure = const NetworkFailure('offline', isTimeout: true);
      final cubit = _cubit(repo);
      await cubit.load();
      await cubit.approve('t1');
      expect(repo.pendingCalls, 2);
      expect(cubit.state.decision.kind, TopUpDecisionKind.failed);
      await cubit.close();
    });

    test('a second tap while one decision runs is ignored (money moves once)', () async {
      final gated = _Gated();
      final cubit = SubAgentTopUpsCubit(SubAgentTopUpUseCases(gated));
      await cubit.load();
      final first = cubit.approve('t1');
      await pumpEventQueue();
      await cubit.approve('t1');
      await cubit.approve('t2'); // not even another request while one is running
      gated.gate.complete();
      await first;
      expect(gated.approvals, 1);
      await cubit.close();
    });

    test('an unknown request is ignored', () async {
      final repo = FakeSubAgentTopUpRepository([_item]);
      final cubit = _cubit(repo);
      await cubit.load();
      await cubit.approve('nope');
      expect(repo.approved, isEmpty);
      await cubit.close();
    });
  });

  group('SubAgentTopUpsSection', () {
    Future<FakeSubAgentTopUpRepository> open(WidgetTester tester, List<SubAgentTopUp> items, {VoidCallback? onApproved}) async {
      final repo = FakeSubAgentTopUpRepository(items);
      final cubit = _cubit(repo);
      addTearDown(() => cubit.close().ignore());
      await cubit.load();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Scaffold(
          body: BlocProvider.value(value: cubit, child: SingleChildScrollView(child: SubAgentTopUpsSection(onApproved: onApproved))),
        ),
      ));
      await tester.pump();
      return repo;
    }

    testWidgets('nothing waiting: the section is not drawn', (tester) async {
      await open(tester, const []);
      expect(find.textContaining('طلبات شحن الرصيد'), findsNothing);
    });

    testWidgets('shows who asks and how much; approving asks first, then transfers and tells the list to refresh', (tester) async {
      var refreshed = 0;
      final repo = await open(tester, [_item, _other], onApproved: () => refreshed++);
      expect(find.text('مكتب الريان'), findsOneWidget);
      expect(find.textContaining('250.00'), findsOneWidget);

      await tester.tap(find.text('موافقة').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('سيُخصم'), findsOneWidget); // the confirmation says how much leaves the wallet
      expect(repo.approved, isEmpty);

      await tester.tap(find.text('موافقة وتحويل'));
      await tester.pumpAndSettle();
      expect(repo.approved, ['t1']);
      expect(refreshed, 1);
      expect(find.text('مكتب الريان'), findsNothing);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final repo = await open(tester, [_item]);
      await tester.tap(find.text('موافقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(repo.approved, isEmpty);
      expect(find.text('مكتب الريان'), findsOneWidget);
    });

    testWidgets('rejecting removes the request', (tester) async {
      final repo = await open(tester, [_item]);
      await tester.tap(find.text('رفض'));
      await tester.pumpAndSettle();
      expect(repo.rejected.single.id, 't1');
      expect(find.text('مكتب الريان'), findsNothing);
    });
  });
}
