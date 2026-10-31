// Taking money back from a sub-agency: the document against the contract, and the
// guarantees around the money (one key per action, no second tap, amount within balance).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/data/datasources/sub_agent_reclaim_remote_data_source.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/repositories/sub_agent_reclaim_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/reclaim_from_sub_agent_usecase.dart';
import 'package:seen_booking/features/agents/presentation/bloc/reclaim_cubit.dart';
import 'package:seen_booking/features/agents/presentation/widgets/reclaim_sub_agent_sheet.dart';

import '../../support/scripted_graphql_service.dart';

class _Repo implements SubAgentReclaimRepository {
  Either<Failure, void> result = const Right(null);
  Completer<void>? gate;
  final calls = <({int cents, String key, String? note})>[];

  @override
  Future<Either<Failure, void>> reclaim({required String subAgentId, required int amountCents, required String idempotencyKey, String? note}) async {
    calls.add((cents: amountCents, key: idempotencyKey, note: note));
    await gate?.future;
    return result;
  }
}

ReclaimCubit _cubit(_Repo repo) => ReclaimCubit(ReclaimFromSubAgentUseCase(repo), subAgentId: 'a1');

const _agent = SubAgent(id: 'a1', name: 'مكتب الريان', code: '', balanceCents: 42000, isActive: true);

void main() {
  test('reclaimFromSubAgent carries the decimal amount, the note and the idempotency key', () async {
    final graphql = ScriptedGraphQLService({
      'ReclaimFromSubAgent': {
        'reclaimFromSubAgent': {'id': 'w1'},
      },
    });
    final result = await SubAgentReclaimRemoteDataSource(graphQLService: graphql).reclaim(subAgentId: 'a1', amountCents: 12550, idempotencyKey: 'k1', note: 'اسبوعي');
    expect(result.isRight(), isTrue);
    expect(graphql.where('ReclaimFromSubAgent').single.variables, {'subAgentId': 'a1', 'amount': '125.50', 'note': 'اسبوعي', 'idempotencyKey': 'k1'});
  });

  group('ReclaimCubit', () {
    test('success settles the key: the next action gets a new one', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.submit(amountCents: 1000);
      expect(cubit.state.status, ReclaimStatus.done);
      await cubit.close();

      final again = _cubit(repo);
      await again.submit(amountCents: 1000);
      expect(repo.calls[1].key, isNot(repo.calls[0].key)); // another action, another key
      await again.close();
    });

    test('after a dropped connection the retry of the same action reuses the key; a different amount does not', () async {
      final repo = _Repo()..result = const Left(NetworkFailure('offline', isTimeout: true));
      final cubit = _cubit(repo);
      await cubit.submit(amountCents: 1000);
      expect(cubit.state.status, ReclaimStatus.failed);
      await cubit.submit(amountCents: 1000);
      expect(repo.calls[1].key, repo.calls[0].key);
      await cubit.submit(amountCents: 2000);
      expect(repo.calls[2].key, isNot(repo.calls[0].key));
      await cubit.close();
    });

    test('a clear refusal spends the key', () async {
      final repo = _Repo()..result = const Left(ServerFailure('x', code: 'reclaim_exceeds_balance'));
      final cubit = _cubit(repo);
      await cubit.submit(amountCents: 1000);
      await cubit.submit(amountCents: 1000);
      expect(repo.calls[1].key, isNot(repo.calls[0].key));
      expect((cubit.state.failure as ServerFailure).code, 'reclaim_exceeds_balance');
      await cubit.close();
    });

    test('a second tap while it runs sends nothing more', () async {
      final repo = _Repo()..gate = Completer<void>();
      final cubit = _cubit(repo);
      final first = cubit.submit(amountCents: 1000);
      await pumpEventQueue();
      await cubit.submit(amountCents: 1000);
      repo.gate!.complete();
      await first;
      expect(repo.calls.length, 1);
      await cubit.close();
    });
  });

  group('ReclaimSubAgentSheet', () {
    Future<_Repo> open(WidgetTester tester) async {
      final repo = _Repo();
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReclaimSubAgentSheet(context, subAgent: _agent, createCubit: () => _cubit(repo)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('an amount above the sub-agency balance is refused before anything is sent', (tester) async {
      final repo = await open(tester);
      expect(find.textContaining('420.00'), findsWidgets);
      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.text('استرداد').last);
      await tester.pump();
      expect(repo.calls, isEmpty);
    });

    testWidgets('a valid amount takes the money back and closes', (tester) async {
      final repo = await open(tester);
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.tap(find.text('استرداد').last);
      await tester.pumpAndSettle();
      expect(repo.calls.single.cents, 10000);
      expect(find.text('تم استرداد المبلغ إلى رصيدك.'), findsOneWidget);
    });
  });
}
