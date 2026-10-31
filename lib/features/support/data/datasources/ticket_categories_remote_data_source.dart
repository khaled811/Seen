import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/ticket_category_option.dart';
import '../../domain/repositories/ticket_categories_repository.dart';

/// `ticketCategories`. The contract has no description or explanation for a category, so a row
/// is just its name.
class TicketCategoriesRemoteDataSource implements TicketCategoriesRepository {
  TicketCategoriesRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _document = gql(r'''
    query TicketCategories { ticketCategories { code nameAr nameEn sortOrder isActive } }
  ''');

  @override
  Future<Either<Failure, List<TicketCategoryOption>>> list() => _graphQL.query<List<TicketCategoryOption>>(QueryOptions<List<TicketCategoryOption>>(
        document: _document,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) {
          final options = [
            for (final c in (j['ticketCategories'] as List<dynamic>).cast<Map<String, dynamic>>())
              if (c['isActive'] != false)
                TicketCategoryOption(
                  code: c['code'] as String,
                  name: _language.pick(ar: c['nameAr'] as String?, en: c['nameEn'] as String?),
                  sortOrder: (c['sortOrder'] as num?)?.toInt() ?? 0,
                ),
          ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return options;
        },
      ));
}
