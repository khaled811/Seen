// A small stateful stand-in for the backend's money operations, for integration tests.
//
// It keeps real balances and counts what actually happened (`effects`), honours the
// idempotency key the way the contract says (same key + same details = the first answer
// again, no second effect; same key + other details = `idempotency_key_reused`), can lose
// an answer after applying it (the dangerous case: the client sees a timeout while the
// money moved), and can hold an answer open (to overlap two taps).
//
// Every document the app sends is validated against the contract first, and the app's
// own parser reads the answer, like `ScriptedGraphQLService` does.

import 'dart:async';

import 'package:fpdart/fpdart.dart';
// ignore: depend_on_referenced_packages
import 'package:gql/ast.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/graphql_service.dart';

import 'contract_schema.dart';

class MoneyServer implements GraphQLService {
  MoneyServer() {
    reset();
  }

  static const mainWallet = 'main';

  late int mainCents;
  late Map<String, int> subCents;
  late Map<String, ({String agent, int cents})> pendingSubTopUps;

  /// What really happened, in order: `topup:<cents>`, `fund:<agent>:<cents>`,
  /// `reclaim:<agent>:<cents>`, `approve:<id>`, `reject:<id>`.
  late List<String> effects;

  /// Operations that reached the server, in order (name only).
  late List<String> received;

  late Map<String, ({String payload, Map<String, dynamic> answer})> _seenKeys;

  /// The next [loseNext] money operations are applied, then answered with a timeout.
  int loseNext = 0;

  /// When set, a money operation waits for it before it answers (it is already counted as received).
  Completer<void>? hold;

  void reset() {
    mainCents = 100000;
    subCents = {'s1': 20000};
    pendingSubTopUps = {'t1': (agent: 's1', cents: 5000)};
    effects = [];
    received = [];
    _seenKeys = {};
    loseNext = 0;
    hold = null;
  }

  static String _money(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  static int _cents(Object? decimal) {
    final parts = '$decimal'.split('.');
    return int.parse(parts[0]) * 100 + (parts.length > 1 ? int.parse(parts[1].padRight(2, '0').substring(0, 2)) : 0);
  }

  @override
  Future<Either<Failure, T>> query<T>(QueryOptions<T> options) => _run(options.document, options.variables, options.parserFn);

  @override
  Future<Either<Failure, T>> mutate<T>(MutationOptions<T> options) => _run(options.document, options.variables, options.parserFn);

  Future<Either<Failure, T>> _run<T>(DocumentNode document, Map<String, dynamic> variables, T Function(Map<String, dynamic>) parserFn) async {
    final op = document.definitions.whereType<OperationDefinitionNode>().first;
    final name = op.name?.value ?? '';
    final problems = ContractSchema.load().validate(document);
    if (problems.isNotEmpty) throw StateError('Operation "$name" does not match the backend contract:\n - ${problems.join('\n - ')}');
    received.add(name);

    final result = await _handle(name, variables);
    if (result is Failure) return Left(result);
    return Right(parserFn(result as Map<String, dynamic>));
  }

  /// A money operation: hold, apply once per key, maybe lose the answer.
  Future<Object> _moneyOp(String? key, String payload, Map<String, dynamic> Function() apply) async {
    final gate = hold;
    if (gate != null) await gate.future;
    if (key != null) {
      final seen = _seenKeys[key];
      if (seen != null) {
        if (seen.payload != payload) return const ServerFailure('Key reused.', code: 'idempotency_key_reused');
        return _maybeLose(seen.answer);
      }
    }
    final answer = apply();
    if (key != null) _seenKeys[key] = (payload: payload, answer: answer);
    return _maybeLose(answer);
  }

  Object _maybeLose(Map<String, dynamic> answer) {
    if (loseNext > 0) {
      loseNext--;
      return const NetworkFailure('timeout', isTimeout: true);
    }
    return answer;
  }

  Future<Object> _handle(String name, Map<String, dynamic> v) async {
    switch (name) {
      case 'WalletSummary':
        return {
          'portalWallet': {
            'summary': {
              'currency': 'USD',
              'balance': _money(mainCents),
              'held': '0.00',
              'total': _money(mainCents),
              'creditLimit': '0.00',
              'spendable': _money(mainCents),
              'creditUsed': '0.00',
            },
          },
        };
      case 'WalletStatement':
        return {
          'portalWallet': {'pendingTopUps': <Object?>[], 'statement': <Object?>[], 'hasMore': false},
        };
      case 'SubmitTopUp':
        return _moneyOp(v['idempotencyKey'] as String?, '${v['amount']}|${v['method']}|${v['referenceNumber']}', () {
          effects.add('topup:${_cents(v['amount'])}');
          return {
            'submitTopUp': {
              'id': 'tx${effects.length}',
              'number': 'TU-${effects.length}',
              'status': 'pending',
              'amount': v['amount'],
              'currency': 'USD',
              'method': v['method'],
              'referenceNumber': v['referenceNumber'],
              'paymentAccount': null,
              'createdAt': '2026-10-21T10:00:00+00:00',
            },
          };
        });
      case 'SubAgents':
        return {
          'portalAgents': {
            'items': [
              for (final e in subCents.entries)
                {
                  'id': e.key,
                  'name': 'Agency ${e.key}',
                  'status': 'active',
                  'city': 'Aden',
                  'ownerName': 'Owner',
                  'requestCount': 0,
                  'monthRequestCount': 0,
                  'balance': _money(e.value),
                  'currency': 'USD',
                  'monthMargin': null,
                  'createdAt': '2026-01-01T00:00:00+00:00',
                  'canFund': true,
                  'canSuspend': true,
                  'canActivate': false,
                },
            ],
          },
        };
      case 'PendingAgentApprovalRequests':
        return {'requests': <Object?>[]};
      case 'TopUpSubAgent':
        return _moneyOp(v['idempotencyKey'] as String?, '${v['subAgentId']}|${v['amount']}|${v['note']}', () {
          final cents = _cents(v['amount']);
          mainCents -= cents;
          subCents[v['subAgentId'] as String] = (subCents[v['subAgentId']] ?? 0) + cents;
          effects.add('fund:${v['subAgentId']}:$cents');
          return {
            'topUpSubAgent': {'id': mainWallet},
          };
        });
      case 'ReclaimFromSubAgent':
        return _moneyOp(v['idempotencyKey'] as String?, '${v['subAgentId']}|${v['amount']}|${v['note']}', () {
          final cents = _cents(v['amount']);
          subCents[v['subAgentId'] as String] = (subCents[v['subAgentId']] ?? 0) - cents;
          mainCents += cents;
          effects.add('reclaim:${v['subAgentId']}:$cents');
          return {
            'reclaimFromSubAgent': {'id': mainWallet},
          };
        });
      case 'PendingSubAgentTopUps':
        return {
          'pendingSubAgentTopUps': [
            for (final e in pendingSubTopUps.entries)
              {
                'id': e.key,
                'status': 'pending',
                'amount': _money(e.value.cents),
                'note': '',
                'createdAt': '2026-10-20T10:00:00+00:00',
                'agent': {'name': 'Agency ${e.value.agent}'},
              },
          ],
        };
      case 'ApproveSubAgentTopUp':
        return _moneyOp(null, '', () {
          final id = v['transactionId'] as String;
          final item = pendingSubTopUps.remove(id);
          if (item == null) throw const _Refused(ServerFailure('Not pending.', code: 'transaction_not_pending'));
          mainCents -= item.cents;
          subCents[item.agent] = (subCents[item.agent] ?? 0) + item.cents;
          effects.add('approve:$id');
          return {
            'approveSubAgentTopUp': {'id': id, 'status': 'approved'},
          };
        }).catchError((Object e) => (e as _Refused).failure);
      case 'RejectSubAgentTopUp':
        return _moneyOp(null, '', () {
          final id = v['transactionId'] as String;
          if (pendingSubTopUps.remove(id) == null) throw const _Refused(ServerFailure('Not pending.', code: 'transaction_not_pending'));
          effects.add('reject:$id');
          return {
            'rejectSubAgentTopUp': {'id': id, 'status': 'rejected'},
          };
        }).catchError((Object e) => (e as _Refused).failure);
    }
    return const ServerFailure('Operation not scripted.', code: 'internal_error');
  }
}

class _Refused implements Exception {
  const _Refused(this.failure);
  final Failure failure;
}
