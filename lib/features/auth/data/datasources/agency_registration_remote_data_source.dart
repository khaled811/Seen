import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/agency_registration.dart';

/// `registerMainAgent(input)` (public): creates a pending Main Agent and its
/// Owner and e-mails a confirmation link. The agency can sign in only after the
/// owner confirms the e-mail and Seen approves it (contract 3.2).
abstract interface class AgencyRegistrationRemoteDataSource {
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  });
}

class AgencyRegistrationRemoteDataSourceImpl implements AgencyRegistrationRemoteDataSource {
  AgencyRegistrationRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  static final _registerDocument = gql(r'''
    mutation RegisterMainAgent($input: MainAgentSignupInput!) {
      registerMainAgent(input: $input) { id status }
    }
  ''');

  @override
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  }) async {
    final result = await _graphQLService.mutate<bool>(MutationOptions<bool>(
      document: _registerDocument,
      variables: {
        'input': {
          'name': draft.agencyName,
          'ownerFullName': draft.managerName,
          'ownerEmail': draft.email,
          'ownerPassword': password,
          'ownerPhone': draft.phone,
          'city': draft.city,
          'licenseNumber': draft.licenseNumber,
          'locale': _language.code == 'en' ? 'en' : 'ar',
          // The server records the accepted versions of both texts.
          'acceptedTerms': consent.acceptedTerms && consent.acceptedPrivacy,
        },
      },
      fetchPolicy: FetchPolicy.noCache,
      parserFn: (json) => (json['registerMainAgent'] as Map<String, dynamic>)['id'] != null,
    ));
    return result.flatMap((created) => created ? const Right(null) : const Left(ServerFailure('Registration was not created.')));
  }
}
