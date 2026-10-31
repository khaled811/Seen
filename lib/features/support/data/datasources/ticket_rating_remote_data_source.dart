import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/repositories/ticket_rating_repository.dart';

/// `rateTicket(ticketId, rating)`.
class TicketRatingRemoteDataSource implements TicketRatingRepository {
  TicketRatingRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _rateDoc = gql(r'''
    mutation RateTicket($ticketId: ID!, $rating: Int!) {
      rateTicket(ticketId: $ticketId, rating: $rating) { ticketId rating ratedAt }
    }
  ''');

  @override
  Future<Either<Failure, void>> rate(String ticketId, int rating) async => (await _graphQL.mutate<int>(MutationOptions<int>(
        document: _rateDoc,
        variables: {'ticketId': ticketId, 'rating': rating},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => ((j['rateTicket'] as Map<String, dynamic>)['rating'] as num).toInt(),
      )))
          .map((_) {});
}
