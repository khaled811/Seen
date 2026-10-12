import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/money.dart';
import '../models/wallet_balance_dto.dart';
import '../models/wallet_transaction_dto.dart';

/// Raw GraphQL access for the wallet feature. Returns DTOs, never entities.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (query/mutation names, argument names, response fields). Update once the
/// real Seen Booking GraphQL schema is confirmed — see the matching TODOs
/// in `wallet_balance_dto.dart` / `wallet_transaction_dto.dart`. Receipt
/// upload is deliberately not wired here yet — mocked/decoupled until the
/// backend's Supabase mutations are active (per Task 06).
abstract interface class WalletRemoteDataSource {
  Future<Either<Failure, WalletBalanceDto>> getBalance();

  Future<Either<Failure, List<WalletTransactionDto>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  });

  Future<Either<Failure, WalletTransactionDto>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  });
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  WalletRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static final _balanceDocument = gql(r'''
    query WalletBalance {
      walletBalance {
        availableAmount
        holdAmount
        creditLimitAmount
        currency
      }
    }
  ''');

  static final _transactionsDocument = gql(r'''
    query WalletTransactions(
      $type: String
      $fromDate: String
      $toDate: String
      $page: Int!
      $pageSize: Int!
    ) {
      walletTransactions(
        type: $type
        fromDate: $fromDate
        toDate: $toDate
        page: $page
        pageSize: $pageSize
      ) {
        id
        type
        side
        status
        amount
        currency
        referenceId
        notes
        createdAt
      }
    }
  ''');

  static final _requestTopUpDocument = gql(r'''
    mutation RequestTopUp(
      $amount: String!
      $method: String!
      $referenceNumber: String!
      $notes: String
    ) {
      requestTopUp(
        amount: $amount
        method: $method
        referenceNumber: $referenceNumber
        notes: $notes
      ) {
        id
        type
        side
        status
        amount
        currency
        referenceId
        notes
        createdAt
      }
    }
  ''');

  @override
  Future<Either<Failure, WalletBalanceDto>> getBalance() {
    return _graphQLService.query<WalletBalanceDto>(
      QueryOptions<WalletBalanceDto>(
        document: _balanceDocument,
        parserFn: (json) =>
            WalletBalanceDto.fromJson(json['walletBalance'] as Map<String, dynamic>),
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
        document: _transactionsDocument,
        variables: {
          'type': type?.value,
          'fromDate': from?.toIso8601String(),
          'toDate': to?.toIso8601String(),
          'page': page,
          'pageSize': pageSize,
        },
        parserFn: (json) => (json['walletTransactions'] as List<dynamic>)
            .map((e) => WalletTransactionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, WalletTransactionDto>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) {
    return _graphQLService.mutate<WalletTransactionDto>(
      MutationOptions<WalletTransactionDto>(
        document: _requestTopUpDocument,
        variables: {
          'amount': MoneyParser.decimalStringFromCents(amountCents),
          'method': method.value,
          'referenceNumber': referenceNumber,
          'notes': notes,
        },
        parserFn: (json) =>
            WalletTransactionDto.fromJson(json['requestTopUp'] as Map<String, dynamic>),
      ),
    );
  }
}
