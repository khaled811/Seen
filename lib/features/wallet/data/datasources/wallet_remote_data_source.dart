import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/statement.dart';
import '../models/portal_wallet_mapping.dart';
import '../models/statement_file_dto.dart';
import '../models/top_up_options_dto.dart';
import '../models/wallet_balance_dto.dart';
import '../models/wallet_transaction_dto.dart';

/// Raw GraphQL access for the wallet feature (`docs/api/mobile-api-reference.md`,
/// "Wallet and top-ups"). Returns DTOs, never entities.
///
/// Money is sent and received as `Decimal` strings and only ever turned into
/// integer cents by the DTO mappers.
abstract interface class WalletRemoteDataSource {
  /// The statement as a PDF (`accountStatementPdf`, needs `data.export`).
  Future<Either<Failure, StatementFileDto>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  });

  /// The API has no operation to withdraw a top-up request: always a failure.
  Future<Either<Failure, WalletTransactionDto>> cancelTopUp(String transactionId);

  Future<Either<Failure, WalletBalanceDto>> getBalance();

  Future<Either<Failure, List<WalletTransactionDto>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  /// `submitTopUp`: the request is pending until Seen approves it; no money
  /// moves now. [idempotencyKey] makes a retry of the same action safe.
  Future<Either<Failure, WalletTransactionDto>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  });

  Future<Either<Failure, TopUpOptionsDto>> getTopUpOptions();
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  WalletRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  /// Code of the failure returned for operations the API does not offer.
  static const String unsupportedCode = 'unsupported_operation';

  static final _summaryDocument = gql(r'''
    query WalletSummary {
      portalWallet(limit: 1) {
        summary {
          currency
          balance
          held
          total
          creditLimit
          spendable
          creditUsed
        }
      }
    }
  ''');

  static final _statementDocument = gql(r'''
    query WalletStatement($type: String, $dateFrom: Date, $dateTo: Date, $limit: Int!, $offset: Int!) {
      portalWallet(filter: "all", type: $type, dateFrom: $dateFrom, dateTo: $dateTo, limit: $limit, offset: $offset) {
        pendingTopUps {
          id
          number
          amount
          currency
          method
          referenceNumber
          paymentAccountTitle
          createdAt
        }
        statement {
          id
          type
          direction
          amount
          currency
          balanceAfter
          createdAt
          requestId
          referenceCode
          serviceNameAr
          serviceNameEn
          method
        }
        hasMore
      }
    }
  ''');

  static final _submitTopUpDocument = gql(r'''
    mutation SubmitTopUp(
      $amount: Decimal!
      $method: String!
      $referenceNumber: String!
      $paymentAccountId: ID
      $receiptFileId: ID
      $idempotencyKey: String
    ) {
      submitTopUp(
        amount: $amount
        method: $method
        referenceNumber: $referenceNumber
        paymentAccountId: $paymentAccountId
        receiptFileId: $receiptFileId
        idempotencyKey: $idempotencyKey
      ) {
        id
        number
        status
        amount
        currency
        method
        referenceNumber
        paymentAccount {
          id
          title
        }
        createdAt
      }
    }
  ''');

  static final _topUpOptionsDocument = gql(r'''
    query TopUpOptions {
      portalTopUpOptions {
        currency
        minimumAmount
        methods {
          method
          accountKinds
        }
        accounts {
          id
          kind
          title
          holder
          bankName
          accountNumber
          currency
          instructions
          isActive
        }
        canRequest
        pendingCount
      }
    }
  ''');

  static final _statementPdfDocument = gql(r'''
    query AccountStatementPdf($dateFrom: Date!, $dateTo: Date!, $language: String!) {
      accountStatementPdf(dateFrom: $dateFrom, dateTo: $dateTo, language: $language) {
        filename
        contentBase64
      }
    }
  ''');

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Either<Failure, WalletBalanceDto>> getBalance() {
    return _graphQLService.query<WalletBalanceDto>(
      QueryOptions<WalletBalanceDto>(
        document: _summaryDocument,
        parserFn: (json) => PortalWalletMapping.balance(
          (json['portalWallet'] as Map<String, dynamic>)['summary'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, List<WalletTransactionDto>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) {
    return _graphQLService.query<List<WalletTransactionDto>>(
      QueryOptions<List<WalletTransactionDto>>(
        document: _statementDocument,
        variables: {
          'type': type?.value,
          'dateFrom': from == null ? null : _day(from),
          'dateTo': to == null ? null : _day(to),
          'limit': pageSize,
          'offset': (page - 1) * pageSize,
        },
        parserFn: (json) {
          final wallet = json['portalWallet'] as Map<String, dynamic>;
          // Top-ups still waiting for Seen are not in the posted statement; they
          // lead the first page of an unfiltered or top-up view.
          final showPending = page == 1 && (type == null || type == TransactionType.topup);
          return [
            if (showPending)
              for (final p in wallet['pendingTopUps'] as List<dynamic>? ?? const [])
                PortalWalletMapping.pendingTopUp(p as Map<String, dynamic>),
            for (final row in wallet['statement'] as List<dynamic>? ?? const [])
              PortalWalletMapping.statementRow(row as Map<String, dynamic>, _language),
          ];
        },
      ),
    );
  }

  @override
  Future<Either<Failure, WalletTransactionDto>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  }) {
    return _graphQLService.mutate<WalletTransactionDto>(
      MutationOptions<WalletTransactionDto>(
        document: _submitTopUpDocument,
        variables: {
          'amount': MoneyParser.decimalStringFromCents(amountCents),
          'method': method.value,
          'referenceNumber': referenceNumber,
          'paymentAccountId': paymentAccountId,
          'receiptFileId': receiptFileId,
          'idempotencyKey': idempotencyKey,
        },
        parserFn: (json) => PortalWalletMapping.submittedTopUp(json['submitTopUp'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, TopUpOptionsDto>> getTopUpOptions() {
    return _graphQLService.query<TopUpOptionsDto>(
      QueryOptions<TopUpOptionsDto>(
        document: _topUpOptionsDocument,
        parserFn: (json) => TopUpOptionsDto.fromJson(json['portalTopUpOptions'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, StatementFileDto>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  }) {
    return _graphQLService.query<StatementFileDto>(
      QueryOptions<StatementFileDto>(
        document: _statementPdfDocument,
        variables: {'dateFrom': _day(from), 'dateTo': _day(to), 'language': _language.code},
        parserFn: (json) => StatementFileDto.fromJson(json['accountStatementPdf'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, WalletTransactionDto>> cancelTopUp(String transactionId) async =>
      const Left(ServerFailure('A top-up request cannot be withdrawn.', code: unsupportedCode));
}
