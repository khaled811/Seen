import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/repositories/email_change_repository.dart';

/// `me { email }` and `requestEmailChange(newEmail, currentPassword, locale)`. The password is
/// sent once and never kept.
class EmailChangeRemoteDataSource implements EmailChangeRepository {
  EmailChangeRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _currentDoc = gql(r'''
    query MyEmail { me { email } }
  ''');

  static final _requestDoc = gql(r'''
    mutation RequestEmailChange($newEmail: String!, $currentPassword: String!, $locale: String!) {
      requestEmailChange(newEmail: $newEmail, currentPassword: $currentPassword, locale: $locale)
    }
  ''');

  @override
  Future<Either<Failure, String>> currentEmail() => _graphQL.query<String>(QueryOptions<String>(
        document: _currentDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => ((j['me'] as Map<String, dynamic>)['email'] as String?) ?? '',
      ));

  @override
  Future<Either<Failure, void>> request({required String newEmail, required String currentPassword}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _requestDoc,
        variables: {'newEmail': newEmail, 'currentPassword': currentPassword, 'locale': _language.code == 'en' ? 'en' : 'ar'},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['requestEmailChange'] == true,
      )))
          .flatMap((sent) => sent ? const Right(null) : const Left(ServerFailure('The link was not sent.', code: 'email_send_failed')));
}
