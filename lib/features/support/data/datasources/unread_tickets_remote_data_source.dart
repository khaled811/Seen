import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/repositories/unread_tickets_repository.dart';

/// `unreadTicketsCount`.
class UnreadTicketsRemoteDataSource implements UnreadTicketsRepository {
  UnreadTicketsRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _document = gql(r'''
    query UnreadTicketsCount { unreadTicketsCount }
  ''');

  @override
  Future<Either<Failure, int>> count() => _graphQL.query<int>(QueryOptions<int>(
        document: _document,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => (j['unreadTicketsCount'] as num).toInt(),
      ));
}
