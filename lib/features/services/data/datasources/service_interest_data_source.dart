import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/repositories/service_interest_repository.dart';

/// GraphQL access for "notify me when available".
///
/// TODO(backend-contract): placeholder mutation `notifyWhenServiceAvailable(serviceKey)`;
/// see docs/BACKEND_MIGRATION_GAPS.md section 41. In a debug build, when the call fails,
/// it is treated as done so the flow can be tried (`kDebugMode` is a compile-time constant).
class ServiceInterestRepositoryImpl implements ServiceInterestRepository {
  ServiceInterestRepositoryImpl({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;
  final _requested = <String>{};

  static final _doc = gql(r'''
    mutation NotifyWhenServiceAvailable($serviceKey: String!) {
      notifyWhenServiceAvailable(serviceKey: $serviceKey) { success }
    }
  ''');

  @override
  Future<Either<Failure, void>> notifyWhenAvailable(String serviceKey) async {
    final r = await _graphQL.mutate<bool>(MutationOptions<bool>(
      document: _doc,
      variables: {'serviceKey': serviceKey},
      parserFn: (j) => (j['notifyWhenServiceAvailable'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
    ));
    if (r.isRight() || (kDebugMode && r.isLeft())) {
      _requested.add(serviceKey);
      return const Right(null);
    }
    return Left(r.swap().getOrElse((_) => const ServerFailure('notify failed')));
  }

  @override
  bool alreadyRequested(String serviceKey) => _requested.contains(serviceKey);
}
