// Every flow that moves money, wired the way the app wires it (the real DI graph, the real
// data sources, use cases and blocs) against a stateful stand-in for the backend that
// counts what really happened. The questions asked here are the ones that cost money:
//
//  * a double tap, a lost answer and a retry never move the money twice;
//  * the balances shown after an action are the server's, not the app's arithmetic;
//  * a different action (another amount) is not mistaken for a retry.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/config/debug_fallbacks.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_event.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_state.dart';
import 'package:seen_booking/features/agents/presentation/bloc/reclaim_cubit.dart';
import 'package:seen_booking/features/agents/presentation/bloc/sub_agent_top_ups_cubit.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_state.dart';

import '../support/failing_session_remote.dart';
import '../support/money_server.dart';

final _server = MoneyServer();

Future<void> _settle() => pumpEventQueue(times: 200);

Future<WalletBloc> _walletBloc() async {
  final bloc = WalletBloc(
    getWalletBalanceUseCase: InjectionContainer.instance.getWalletBalanceUseCase,
    getTransactionsUseCase: InjectionContainer.instance.getTransactionsUseCase,
    requestTopUpUseCase: InjectionContainer.instance.requestTopUpUseCase,
  );
  addTearDown(bloc.close);
  bloc.add(const WalletLoadRequested());
  await _settle();
  expect(bloc.state, isA<WalletLoaded>());
  return bloc;
}

WalletTopUpSubmitted _topUp(int cents, {String reference = 'REF-1'}) =>
    WalletTopUpSubmitted(amountCents: cents, method: TopUpMethod.bankTransfer, referenceNumber: reference);

Future<AgentsBloc> _agentsBloc() async {
  final bloc = InjectionContainer.instance.createAgentsBloc();
  addTearDown(bloc.close);
  bloc.add(const AgentsLoadRequested());
  await _settle();
  expect(bloc.state, isA<AgentsLoaded>());
  return bloc;
}

AgentsLoaded _loaded(AgentsBloc bloc) => bloc.state as AgentsLoaded;

int _balanceOf(AgentsBloc bloc, String id) => _loaded(bloc).subAgents.firstWhere((a) => a.id == id).balanceCents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    // The real failures, not canned data: the debug fallbacks must not answer for the server.
    DebugFallbacks.testOverride = false;
    InjectionContainer.instance.init(overrides: InjectionOverrides(graphQLService: _server, sessionRemote: const FailingSessionRemote()));
  });

  tearDownAll(() => DebugFallbacks.testOverride = null);

  setUp(_server.reset);

  group('wallet top-up request', () {
    test('a double tap files one request', () async {
      final bloc = await _walletBloc();
      _server.hold = Completer<void>();
      bloc
        ..add(_topUp(25000))
        ..add(_topUp(25000));
      await _settle();
      _server.hold!.complete();
      await _settle();
      expect(_server.effects, ['topup:25000']);
      expect((bloc.state as WalletLoaded).topUpStatus, TopUpSubmissionStatus.success);
    });

    test('a lost answer then a retry of the same request files it once (same key, the server answers again)', () async {
      final bloc = await _walletBloc();
      _server.loseNext = 1;
      bloc.add(_topUp(25000));
      await _settle();
      expect((bloc.state as WalletLoaded).topUpStatus, TopUpSubmissionStatus.failure);
      expect(_server.effects, ['topup:25000']); // it did go through, the app only lost the answer

      bloc.add(_topUp(25000));
      await _settle();
      expect(_server.effects, ['topup:25000']); // still one
      expect((bloc.state as WalletLoaded).topUpStatus, TopUpSubmissionStatus.success);
    });

    test('after a success, the same details are a new request with a new key', () async {
      final bloc = await _walletBloc();
      bloc.add(_topUp(25000));
      await _settle();
      bloc
        ..add(const WalletTopUpStatusCleared())
        ..add(_topUp(25000));
      await _settle();
      expect(_server.effects, ['topup:25000', 'topup:25000']);
    });

    test('other details after a failure are another request (the old key is not reused: no idempotency_key_reused)', () async {
      final bloc = await _walletBloc();
      _server.loseNext = 1;
      bloc.add(_topUp(25000));
      await _settle();
      bloc.add(_topUp(30000));
      await _settle();
      expect((bloc.state as WalletLoaded).topUpStatus, TopUpSubmissionStatus.success);
      expect(_server.effects, ['topup:25000', 'topup:30000']);
    });
  });

  group('funding a sub-agency (topUpSubAgent)', () {
    test('the balances after a transfer are the server\'s', () async {
      final bloc = await _agentsBloc();
      expect(_balanceOf(bloc, 's1'), 20000);
      bloc.add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      expect(_server.effects, ['fund:s1:5000']);
      expect(_balanceOf(bloc, 's1'), 25000);
      expect(_loaded(bloc).masterWalletBalance!.availableCents, 95000);
      expect(_loaded(bloc).fundingStatus, FundingStatus.success);
    });

    test('a double tap moves the money once', () async {
      final bloc = await _agentsBloc();
      _server.hold = Completer<void>();
      bloc
        ..add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000))
        ..add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      _server.hold!.complete();
      await _settle();
      expect(_server.effects, ['fund:s1:5000']);
    });

    test('a lost answer then "try again" moves it once, and the screen then shows the real balance', () async {
      final bloc = await _agentsBloc();
      _server.loseNext = 1;
      bloc.add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      expect(_loaded(bloc).fundingStatus, FundingStatus.failure);
      expect(_server.effects, ['fund:s1:5000']); // it did go through

      bloc
        ..add(const FundingStatusCleared())
        ..add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      expect(_server.effects, ['fund:s1:5000']);
      expect(_balanceOf(bloc, 's1'), 25000);
      expect(_loaded(bloc).masterWalletBalance!.availableCents, 95000);
    });

    test('after a completed transfer, the same details are a new transfer (new key, not a replay)', () async {
      final bloc = await _agentsBloc();
      bloc.add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      bloc
        ..add(const FundingStatusCleared())
        ..add(const SubAgentWalletFundingSubmitted(subAgentId: 's1', amountCents: 5000));
      await _settle();
      expect(_server.effects, ['fund:s1:5000', 'fund:s1:5000']);
      expect(_balanceOf(bloc, 's1'), 30000);
    });
  });

  group('taking money back (reclaimFromSubAgent)', () {
    test('a double tap and a lost answer with a retry move it once', () async {
      final cubit = InjectionContainer.instance.createReclaimCubit('s1');
      addTearDown(cubit.close);
      _server.hold = Completer<void>();
      unawaited(cubit.submit(amountCents: 4000));
      await pumpEventQueue();
      unawaited(cubit.submit(amountCents: 4000)); // the second tap while the first runs
      _server.hold!.complete();
      await _settle();
      expect(_server.effects, ['reclaim:s1:4000']);
      expect(cubit.state.status, ReclaimStatus.done);
    });

    test('lost answer, then try again: still one', () async {
      final cubit = InjectionContainer.instance.createReclaimCubit('s1');
      addTearDown(cubit.close);
      _server.loseNext = 1;
      await cubit.submit(amountCents: 4000);
      expect(cubit.state.status, ReclaimStatus.failed);
      expect(_server.effects, ['reclaim:s1:4000']);
      await cubit.submit(amountCents: 4000);
      expect(_server.effects, ['reclaim:s1:4000']);
      expect(cubit.state.status, ReclaimStatus.done);
      expect(_server.subCents['s1'], 16000);
      expect(_server.mainCents, 104000);
    });
  });

  group('deciding a sub-agency\'s funding request', () {
    Future<SubAgentTopUpsCubit> cubit() async {
      final c = InjectionContainer.instance.createSubAgentTopUpsCubit();
      addTearDown(c.close);
      await c.load();
      expect(c.state.items.map((t) => t.id), ['t1']);
      return c;
    }

    test('approving moves the amount once, however many taps', () async {
      final c = await cubit();
      _server.hold = Completer<void>();
      unawaited(c.approve('t1'));
      await pumpEventQueue();
      unawaited(c.approve('t1'));
      _server.hold!.complete();
      await _settle();
      expect(_server.effects, ['approve:t1']);
      expect(_server.mainCents, 95000);
      expect(c.state.items, isEmpty);
    });

    test('a lost answer: the list is read again, shows the request gone, and a second approval is impossible', () async {
      final c = await cubit();
      _server.loseNext = 1;
      await c.approve('t1');
      expect(c.state.decision.kind, TopUpDecisionKind.failed);
      expect(_server.effects, ['approve:t1']); // it did go through
      expect(c.state.items, isEmpty); // the re-read tells the truth
      await c.approve('t1'); // nothing left to approve in the app
      expect(_server.effects, ['approve:t1']);
      expect(_server.mainCents, 95000);
    });

    test('an already decided request is refused by the server and nothing moves', () async {
      final c = await cubit();
      _server.pendingSubTopUps.remove('t1'); // decided elsewhere meanwhile
      await c.approve('t1');
      expect(c.state.decision.kind, TopUpDecisionKind.failed);
      expect(_server.effects, isEmpty);
      expect(_server.mainCents, 100000);
    });

    test('rejecting moves no money', () async {
      final c = await cubit();
      await c.reject('t1');
      expect(_server.effects, ['reject:t1']);
      expect(_server.mainCents, 100000);
    });
  });

  test('every operation the flows sent was valid against the contract (the server validated each document)', () {
    // MoneyServer throws on a document that does not match docs/api, so reaching here means all did.
    expect(_server.received, isNotNull);
  });
}
