// The wallet data source against the backend contract: the documents are
// validated against `docs/api/mobile-api-reference.md`, and the mapping runs on
// realistic answers.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:seen_booking/features/wallet/data/repositories/statement_repository_impl.dart';
import 'package:seen_booking/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:seen_booking/features/wallet/domain/entities/statement.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, Object> _answers() => {
      'WalletSummary': {
        'portalWallet': {
          'summary': {
            'currency': 'USD',
            'balance': '5420.50',
            'held': '350.00',
            'total': '5770.50',
            'creditLimit': '1000.00',
            'spendable': '6420.50',
            'creditUsed': '0.00',
          },
        },
      },
      'WalletStatement': {
        'portalWallet': {
          'pendingTopUps': [
            {
              'id': 'p1',
              'number': 'TU-9',
              'amount': '1500.00',
              'currency': 'USD',
              'method': 'bank_transfer',
              'referenceNumber': 'KR-1',
              'paymentAccountTitle': 'Kuraimi',
              'createdAt': '2026-10-18T14:03:00+00:00',
            },
          ],
          'statement': [
            {
              'id': 's1',
              'type': 'final_deduction',
              'direction': 'debit',
              'amount': '275.00',
              'currency': 'USD',
              'balanceAfter': '3145.00',
              'createdAt': '2026-10-17T10:00:00+00:00',
              'requestId': 'r1',
              'referenceCode': 'SB-20481',
              'serviceNameAr': 'تأشيرة',
              'serviceNameEn': 'Visa',
              'method': null,
            },
            {
              'id': 's2',
              'type': 'topup',
              'direction': 'credit',
              'amount': '2000.00',
              'currency': 'USD',
              'balanceAfter': '5420.00',
              'createdAt': '2026-10-10T10:00:00+00:00',
              'requestId': null,
              'referenceCode': null,
              'serviceNameAr': null,
              'serviceNameEn': null,
              'method': 'bank_transfer',
            },
          ],
          'hasMore': false,
        },
      },
      'SubmitTopUp': {
        'submitTopUp': {
          'id': 't9',
          'number': 'TU-10',
          'status': 'pending',
          'amount': '150.00',
          'currency': 'USD',
          'method': 'bank_transfer',
          'referenceNumber': 'REF-1',
          'paymentAccount': {'id': 'a1', 'title': 'Kuraimi'},
          'createdAt': '2026-10-19T09:00:00+00:00',
        },
      },
      'TopUpOptions': {
        'portalTopUpOptions': {
          'currency': 'USD',
          'minimumAmount': '10.00',
          'methods': [
            {'method': 'bank_transfer', 'accountKinds': ['bank']},
            {'method': 'pigeon_post', 'accountKinds': ['other']},
          ],
          'accounts': [
            {
              'id': 'a1',
              'kind': 'bank',
              'title': 'Kuraimi',
              'holder': 'Seen Booking',
              'bankName': 'Kuraimi Bank',
              'accountNumber': 'YE00 1234',
              'currency': 'USD',
              'instructions': '',
              'isActive': true,
            },
            {
              'id': 'a2',
              'kind': 'bank',
              'title': 'Old',
              'holder': '',
              'bankName': '',
              'accountNumber': '',
              'currency': 'USD',
              'instructions': '',
              'isActive': false,
            },
          ],
          'canRequest': true,
          'pendingCount': 1,
        },
      },
      'AccountStatementPdf': {
        'accountStatementPdf': {'filename': 'statement.pdf', 'contentBase64': base64Encode([37, 80, 68, 70])},
      },
    };

void main() {
  late ScriptedGraphQLService service;
  late WalletRemoteDataSourceImpl remote;
  late AppLanguage language;

  setUp(() {
    service = ScriptedGraphQLService(_answers());
    language = AppLanguage('en');
    remote = WalletRemoteDataSourceImpl(graphQLService: service, language: language);
  });

  group('balance', () {
    test('maps the summary and keeps the server figures, parsed without doubles', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final balance = (await repo.getBalance()).toNullable()!;

      expect(balance.availableCents, 542050);
      expect(balance.holdCents, 35000);
      expect(balance.creditLimitCents, 100000);
      expect(balance.reportedTotalCents, 577050);
      expect(balance.totalCents, 577050);
      expect(balance.spendableCents, 642050);
      expect(balance.currency, WalletCurrency.usd);
    });
  });

  group('transactions', () {
    test('first page of everything: pending top-ups lead, then the statement rows', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final list = (await repo.getTransactions()).toNullable()!;

      expect(list.map((t) => t.id), ['p1', 's1', 's2']);
      final pending = list.first;
      expect((pending.status, pending.type, pending.side), (TransactionStatus.pending, TransactionType.topup, LedgerSide.credit));
      expect(pending.amountCents, 150000);
      expect(pending.topUp?.method, TopUpMethod.bankTransfer);
      expect(pending.topUp?.transferReference, 'KR-1');
      expect(pending.topUp?.bankName, 'Kuraimi');

      final deduction = list[1];
      expect((deduction.status, deduction.side, deduction.type), (TransactionStatus.approved, LedgerSide.debit, TransactionType.finalDeduction));
      expect(deduction.balanceAfterCents, 314500);
      expect(deduction.request?.referenceId, 'SB-20481');
      expect(deduction.request?.serviceName, 'Visa');
      expect(list[2].request, isNull);
      expect(list[2].topUp?.method, TopUpMethod.bankTransfer);
    });

    test('the service name follows the app language', () async {
      language.code = 'ar';

      final list = (await WalletRepositoryImpl(remote: remote).getTransactions()).toNullable()!;

      expect(list[1].request?.serviceName, 'تأشيرة');
    });

    test('paging is an offset; pending top-ups are only on the first page', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final page3 = (await repo.getTransactions(page: 3, pageSize: 20)).toNullable()!;

      expect(page3.map((t) => t.id), ['s1', 's2']);
      expect(service.where('WalletStatement').single.variables, containsPair('offset', 40));
      expect(service.where('WalletStatement').single.variables, containsPair('limit', 20));
    });

    test('a type that cannot be pending does not show pending top-ups', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final list = (await repo.getTransactions(type: TransactionType.hold)).toNullable()!;

      expect(list.map((t) => t.id), ['s1', 's2']);
      expect(service.where('WalletStatement').single.variables, containsPair('type', 'hold'));
    });

    test('dates are sent as YYYY-MM-DD', () async {
      await WalletRepositoryImpl(remote: remote).getTransactions(from: DateTime(2026, 3, 5), to: DateTime(2026, 10, 19));

      final vars = service.where('WalletStatement').single.variables;
      expect(vars['dateFrom'], '2026-03-05');
      expect(vars['dateTo'], '2026-10-19');
    });
  });

  group('top-up', () {
    test('sends a Decimal string amount, the account, the receipt and the idempotency key', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final created = (await repo.requestTopUp(
        amountCents: 15000,
        method: TopUpMethod.bankTransfer,
        referenceNumber: 'REF-1',
        idempotencyKey: 'key-1',
        paymentAccountId: 'a1',
        receiptFileId: 'f1',
      ))
          .toNullable()!;

      expect(service.where('SubmitTopUp').single.variables, {
        'amount': '150.00',
        'method': 'bank_transfer',
        'referenceNumber': 'REF-1',
        'paymentAccountId': 'a1',
        'receiptFileId': 'f1',
        'idempotencyKey': 'key-1',
      });
      expect(created.status, TransactionStatus.pending);
      expect(created.amountCents, 15000);
      expect(created.referenceId, 'TU-10');
    });

    test('options keep active accounts, drop methods the app has no card for, and map the minimum', () async {
      final repo = WalletRepositoryImpl(remote: remote);

      final options = (await repo.getTopUpOptions()).toNullable()!;

      expect(options.accounts.map((a) => a.id), ['a1']);
      expect(options.methods.map((m) => m.method), [TopUpMethod.bankTransfer]);
      expect(options.minimumAmountCents, 1000);
      expect(options.canRequest, isTrue);
      expect(options.pendingCount, 1);
    });

    test('the server failure of a refused top-up is passed on with its code', () async {
      final failing = ScriptedGraphQLService({'SubmitTopUp': const ServerFailure('x', code: 'topup_below_minimum')});
      final repo = WalletRepositoryImpl(
        remote: WalletRemoteDataSourceImpl(graphQLService: failing, language: language),
      );

      final result = await repo.requestTopUp(
        amountCents: 100,
        method: TopUpMethod.bankTransfer,
        referenceNumber: 'R',
        idempotencyKey: 'k',
      );

      expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, 'topup_below_minimum');
    });

    test('a top-up request cannot be withdrawn: there is no operation, and nothing is sent', () async {
      final result = await remote.cancelTopUp('t1');

      expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, WalletRemoteDataSourceImpl.unsupportedCode);
      expect(service.sent, isEmpty);
    });
  });

  group('statement', () {
    test('asks for the PDF in the app language and decodes the file', () async {
      language.code = 'ar';
      final repo = StatementRepositoryImpl(remote: remote);

      final file = (await repo.exportStatement(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 14),
        format: StatementFormat.pdf,
      ))
          .toNullable()!;

      expect(file.fileName, 'statement.pdf');
      expect(file.bytes, [37, 80, 68, 70]);
      expect(service.where('AccountStatementPdf').single.variables, {
        'dateFrom': '2026-10-01',
        'dateTo': '2026-10-14',
        'language': 'ar',
      });
    });

    test('content that is not base64 is a clean failure, not a crash', () async {
      final broken = ScriptedGraphQLService({
        'AccountStatementPdf': {
          'accountStatementPdf': {'filename': 'x.pdf', 'contentBase64': '***not base64***'},
        },
      });
      final repo = StatementRepositoryImpl(
        remote: WalletRemoteDataSourceImpl(graphQLService: broken, language: language),
      );

      final result = await repo.exportStatement(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 2),
        format: StatementFormat.pdf,
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
