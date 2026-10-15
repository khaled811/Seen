import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/agency_registration.dart';
import '../models/registration_challenge_dto.dart';

/// Raw GraphQL access for agency self-registration.
///
/// TODO(backend-contract): the mutation names (`startAgencyRegistration`,
/// `resendRegistrationCode`, `verifyRegistrationPhone`,
/// `completeAgencyRegistration`), their arguments and the error codes mapped in
/// `RegistrationIssue` are a placeholder until the real schema exists
/// (docs/BACKEND_MIGRATION_GAPS.md, section 9).
abstract interface class AgencyRegistrationRemoteDataSource {
  Future<Either<Failure, RegistrationChallengeDto>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  });

  Future<Either<Failure, RegistrationChallengeDto>> resendCode({required String challengeToken});

  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code});

  Future<Either<Failure, void>> complete({required String verificationToken, required RegistrationConsent consent});
}

class AgencyRegistrationRemoteDataSourceImpl implements AgencyRegistrationRemoteDataSource {
  AgencyRegistrationRemoteDataSourceImpl({required GraphQLService graphQLService}) : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _challengeFields = r'''
    challengeToken
    maskedPhone
    resendCooldownSeconds
  ''';

  static final _startDocument = gql('''
    mutation StartAgencyRegistration(\$input: AgencyRegistrationInput!) {
      startAgencyRegistration(input: \$input) { $_challengeFields }
    }
  ''');

  static final _resendDocument = gql('''
    mutation ResendRegistrationCode(\$challengeToken: String!) {
      resendRegistrationCode(challengeToken: \$challengeToken) { $_challengeFields }
    }
  ''');

  static final _verifyDocument = gql(r'''
    mutation VerifyRegistrationPhone($challengeToken: String!, $code: String!) {
      verifyRegistrationPhone(challengeToken: $challengeToken, code: $code) { verificationToken }
    }
  ''');

  static final _completeDocument = gql(r'''
    mutation CompleteAgencyRegistration($verificationToken: String!, $consent: RegistrationConsentInput!) {
      completeAgencyRegistration(verificationToken: $verificationToken, consent: $consent) { success }
    }
  ''');

  @override
  Future<Either<Failure, RegistrationChallengeDto>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  }) =>
      _graphQLService.mutate<RegistrationChallengeDto>(MutationOptions<RegistrationChallengeDto>(
        document: _startDocument,
        variables: {
          'input': {
            'agencyName': draft.agencyName,
            'managerName': draft.managerName,
            'phone': draft.phone,
            'email': draft.email,
            'city': draft.city,
            'licenseNumber': draft.licenseNumber,
            'password': password,
          },
        },
        parserFn: (json) =>
            RegistrationChallengeDto.fromJson(json['startAgencyRegistration'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, RegistrationChallengeDto>> resendCode({required String challengeToken}) =>
      _graphQLService.mutate<RegistrationChallengeDto>(MutationOptions<RegistrationChallengeDto>(
        document: _resendDocument,
        variables: {'challengeToken': challengeToken},
        parserFn: (json) =>
            RegistrationChallengeDto.fromJson(json['resendRegistrationCode'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code}) =>
      _graphQLService.mutate<String>(MutationOptions<String>(
        document: _verifyDocument,
        variables: {'challengeToken': challengeToken, 'code': code},
        parserFn: (json) =>
            (json['verifyRegistrationPhone'] as Map<String, dynamic>)['verificationToken'] as String,
      ));

  @override
  Future<Either<Failure, void>> complete({
    required String verificationToken,
    required RegistrationConsent consent,
  }) async {
    final result = await _graphQLService.mutate<bool>(MutationOptions<bool>(
      document: _completeDocument,
      variables: {
        'verificationToken': verificationToken,
        'consent': {
          'acceptedTerms': consent.acceptedTerms,
          'acceptedPrivacy': consent.acceptedPrivacy,
          'marketing': consent.marketing,
        },
      },
      parserFn: (json) => (json['completeAgencyRegistration'] as Map<String, dynamic>)['success'] as bool? ?? false,
    ));
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('Registration was not submitted.')));
  }
}
