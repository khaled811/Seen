import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/graphql_service.dart';

/// A [GraphQLService] that never touches the network: every operation fails
/// immediately with the same failure a refused HTTP call produces
/// (`ServerFailure`, status 400, which is what `flutter test` returns for any
/// real HTTP request).
///
/// Tests that pump the real app via `InjectionContainer` use this so their
/// outcome never depends on DNS, the sandbox HTTP stub or a placeholder host.
/// Tests that need data supply their own fake data source instead.
class FailingGraphQLService implements GraphQLService {
  const FailingGraphQLService();

  static const Failure _failure = ServerFailure('Server returned 400.', statusCode: 400);

  @override
  Future<Either<Failure, T>> query<T>(QueryOptions<T> options) async => const Left(_failure);

  @override
  Future<Either<Failure, T>> mutate<T>(MutationOptions<T> options) async => const Left(_failure);
}
