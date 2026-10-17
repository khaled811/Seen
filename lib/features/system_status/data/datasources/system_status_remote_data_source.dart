import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/app_status_dto.dart';

/// Raw GraphQL access for app status and access requests.
///
/// TODO(backend-contract): placeholder schema (names and fields); see
/// docs/BACKEND_MIGRATION_GAPS.md section 32.
abstract interface class SystemStatusRemoteDataSource {
  Future<Either<Failure, AppStatusDto>> getAppStatus();

  Future<Either<Failure, bool>> requestAccess(String area);
}

class SystemStatusRemoteDataSourceImpl implements SystemStatusRemoteDataSource {
  SystemStatusRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _statusDocument = gql(r'''
    query AppStatus($platform: String!) {
      appStatus(platform: $platform) {
        maintenance { active etaAt }
        minimumVersion
        latestVersion
        storeUrl
        updateNote
      }
    }
  ''');

  static final _requestAccessDocument = gql(r'''
    mutation RequestAccess($area: String!) {
      requestAccess(area: $area) { success }
    }
  ''');

  @override
  Future<Either<Failure, AppStatusDto>> getAppStatus() {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    return _graphQL.query<AppStatusDto>(
      QueryOptions<AppStatusDto>(
        document: _statusDocument,
        variables: {'platform': platform},
        // Never serve a cached "all clear" while the server is in maintenance.
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) =>
            AppStatusDto.fromJson(json['appStatus'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> requestAccess(String area) {
    return _graphQL.mutate<bool>(
      MutationOptions<bool>(
        document: _requestAccessDocument,
        variables: {'area': area},
        parserFn: (json) =>
            (json['requestAccess'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      ),
    );
  }
}
