import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';

/// `requestPasswordReset(email, locale)` (public). It always answers `true` (no
/// account enumeration) and e-mails a link to a web page; the app has no code
/// step and cannot finish the reset itself (no deep links, contract 3.3).
abstract interface class PasswordRecoveryRemoteDataSource {
  Future<Either<Failure, void>> requestReset({required String email});
}

class PasswordRecoveryRemoteDataSourceImpl implements PasswordRecoveryRemoteDataSource {
  PasswordRecoveryRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  static final _requestDocument = gql(r'''
    mutation RequestPasswordReset($email: String!, $locale: String!) {
      requestPasswordReset(email: $email, locale: $locale)
    }
  ''');

  @override
  Future<Either<Failure, void>> requestReset({required String email}) async {
    final result = await _graphQLService.mutate<bool>(MutationOptions<bool>(
      document: _requestDocument,
      variables: {'email': email, 'locale': _language.code == 'en' ? 'en' : 'ar'},
      fetchPolicy: FetchPolicy.noCache,
      parserFn: (json) => json['requestPasswordReset'] == true,
    ));
    // The contract says it always answers true; anything else is not a success to show.
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('The request was not accepted.')));
  }
}
