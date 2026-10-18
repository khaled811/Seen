import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';

/// GraphQL access to hospital availability.
///
/// TODO(backend-contract): placeholder query `hospitalAvailability(serviceId)`; see
/// docs/BACKEND_MIGRATION_GAPS.md section 44.
class HospitalRemoteDataSource implements HospitalRepository {
  HospitalRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _doc = gql(r'''
    query HospitalAvailability($serviceId: ID!) {
      hospitalAvailability(serviceId: $serviceId) { id name capacity remaining }
    }
  ''');

  @override
  Future<Either<Failure, List<Hospital>>> availability(String serviceId) =>
      _graphQL.query<List<Hospital>>(QueryOptions<List<Hospital>>(
        document: _doc,
        variables: {'serviceId': serviceId},
        // Places change by the hour: never a cached answer.
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => [
          for (final h in (j['hospitalAvailability'] as List<dynamic>).cast<Map<String, dynamic>>())
            Hospital(
              id: h['id'] as String,
              name: h['name'] as String? ?? '',
              capacity: (h['capacity'] as num?)?.toInt() ?? 0,
              remaining: (h['remaining'] as num?)?.toInt() ?? 0,
            ),
        ],
      ));
}

/// DEBUG ONLY: when the call fails in a debug build, answers with the three hospitals of the
/// Figma frame. Release builds drop the branch (`kDebugMode` is a compile-time constant).
class DebugFallbackHospitalRepository implements HospitalRepository {
  DebugFallbackHospitalRepository(this._real);

  final HospitalRepository _real;

  @override
  Future<Either<Failure, List<Hospital>>> availability(String serviceId) async {
    final r = await _real.availability(serviceId);
    if (kDebugMode && r.isLeft()) {
      return const Right([
        Hospital(id: 'h1', name: 'مستشفى الأردن', capacity: 40, remaining: 12),
        Hospital(id: 'h2', name: 'المستشفى التخصصي', capacity: 30, remaining: 3),
        Hospital(id: 'h3', name: 'مستشفى الخالدي', capacity: 25, remaining: 0),
      ]);
    }
    return r;
  }
}
