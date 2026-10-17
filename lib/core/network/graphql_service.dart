import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';

import '../error/failure.dart';
import 'data_freshness.dart';
import 'graphql_client_factory.dart';
import 'graphql_failure_mapper.dart';

/// Functional wrapper around [GraphQLClient]. DataSources call this — never
/// the raw client — so every query/mutation surfaces failures the same way:
/// `Either<Failure, T>`. No direct UI coupling: this class knows nothing
/// about widgets, navigation, or Blocs.
class GraphQLService {
  GraphQLService({required GraphQLClientFactory clientFactory, Logger? logger, DataFreshness? freshness})
      : _clientFactory = clientFactory,
        _logger = logger ?? Logger(),
        _freshness = freshness;

  final GraphQLClientFactory _clientFactory;
  final Logger _logger;
  final DataFreshness? _freshness;

  GraphQLClient get _client => _clientFactory.client;

  /// Executes [options] and returns its parsed data, or a [Failure].
  ///
  /// [options] must be built with a `parserFn` (mapping raw JSON to a
  /// DTO/entity) — this layer has no knowledge of response shapes.
  Future<Either<Failure, T>> query<T>(QueryOptions<T> options) =>
      _run<T>(() => _client.query<T>(options));

  /// Executes [options] and returns its parsed data, or a [Failure].
  Future<Either<Failure, T>> mutate<T>(MutationOptions<T> options) =>
      _run<T>(() => _client.mutate<T>(options));

  Future<Either<Failure, T>> _run<T>(
    Future<QueryResult<T>> Function() operation,
  ) async {
    try {
      final result = await operation();
      if (result.hasException) {
        return Left(mapOperationExceptionToFailure(result.exception!));
      }
      final parsed = result.parsedData;
      if (parsed == null) {
        return const Left(ServerFailure('Empty response from server.'));
      }
      _freshness?.markFresh();
      return Right(parsed);
    } catch (e, st) {
      // Anything not already surfaced as an OperationException (e.g. a bug
      // in a caller-supplied parserFn) must still never crash the app.
      _logger.e('Unhandled GraphQL error', error: e, stackTrace: st);
      return Left(ServerFailure(e.toString()));
    }
  }
}
