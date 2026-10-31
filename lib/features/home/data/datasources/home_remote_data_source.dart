import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/home_service.dart';
import '../../domain/repositories/home_repository.dart';

/// `portalHome` (`docs/api/mobile-api-reference.md`): the home screen's data in one round
/// trip. The balance, the requests and the unread count come from their own screens'
/// operations; this reads the service shortcuts.
class HomeRemoteDataSource implements HomeRepository {
  HomeRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _doc = gql(r'''
    query HomeServices($limit: Int!) {
      portalHome(servicesLimit: $limit, recentLimit: 1) {
        services { id nameAr nameEn category }
      }
    }
  ''');

  @override
  Future<Either<Failure, List<HomeService>>> services({int limit = 6}) => _graphQL.query<List<HomeService>>(
        QueryOptions<List<HomeService>>(
          document: _doc,
          variables: {'limit': limit},
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => [
            for (final s in ((j['portalHome'] as Map<String, dynamic>)['services'] as List<dynamic>).cast<Map<String, dynamic>>())
              HomeService(
                id: s['id'] as String,
                name: _language.pick(ar: s['nameAr'] as String?, en: s['nameEn'] as String?),
                category: s['category'] as String? ?? '',
              ),
          ],
        ),
      );
}
