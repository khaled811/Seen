import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/recovery_challenge_dto.dart';

/// Raw GraphQL access for "forgot password".
///
/// TODO(backend-contract): the mutation names (`requestPasswordReset`,
/// `resendPasswordReset`, `verifyPasswordReset`, `resetPassword`), their
/// arguments and the error codes mapped in `RecoveryIssue` are a placeholder
/// until the real schema exists (docs/BACKEND_MIGRATION_GAPS.md, section 7).
abstract interface class PasswordRecoveryRemoteDataSource {
  Future<Either<Failure, RecoveryChallengeDto>> requestCode({required String identifier});

  Future<Either<Failure, RecoveryChallengeDto>> resendCode({required String challengeToken});

  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code});

  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword});
}

class PasswordRecoveryRemoteDataSourceImpl implements PasswordRecoveryRemoteDataSource {
  PasswordRecoveryRemoteDataSourceImpl({required GraphQLService graphQLService}) : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _challengeFields = r'''
    challengeToken
    maskedDestination
    resendCooldownSeconds
  ''';

  static final _requestDocument = gql('''
    mutation RequestPasswordReset(\$identifier: String!) {
      requestPasswordReset(identifier: \$identifier) { $_challengeFields }
    }
  ''');

  static final _resendDocument = gql('''
    mutation ResendPasswordReset(\$challengeToken: String!) {
      resendPasswordReset(challengeToken: \$challengeToken) { $_challengeFields }
    }
  ''');

  static final _verifyDocument = gql(r'''
    mutation VerifyPasswordReset($challengeToken: String!, $code: String!) {
      verifyPasswordReset(challengeToken: $challengeToken, code: $code) { resetToken }
    }
  ''');

  static final _resetDocument = gql(r'''
    mutation ResetPassword($resetToken: String!, $newPassword: String!) {
      resetPassword(resetToken: $resetToken, newPassword: $newPassword) { success }
    }
  ''');

  @override
  Future<Either<Failure, RecoveryChallengeDto>> requestCode({required String identifier}) =>
      _graphQLService.mutate<RecoveryChallengeDto>(MutationOptions<RecoveryChallengeDto>(
        document: _requestDocument,
        variables: {'identifier': identifier},
        parserFn: (json) => RecoveryChallengeDto.fromJson(json['requestPasswordReset'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, RecoveryChallengeDto>> resendCode({required String challengeToken}) =>
      _graphQLService.mutate<RecoveryChallengeDto>(MutationOptions<RecoveryChallengeDto>(
        document: _resendDocument,
        variables: {'challengeToken': challengeToken},
        parserFn: (json) => RecoveryChallengeDto.fromJson(json['resendPasswordReset'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, String>> verifyCode({required String challengeToken, required String code}) =>
      _graphQLService.mutate<String>(MutationOptions<String>(
        document: _verifyDocument,
        variables: {'challengeToken': challengeToken, 'code': code},
        parserFn: (json) => (json['verifyPasswordReset'] as Map<String, dynamic>)['resetToken'] as String,
      ));

  @override
  Future<Either<Failure, void>> resetPassword({required String resetToken, required String newPassword}) async {
    final result = await _graphQLService.mutate<bool>(MutationOptions<bool>(
      document: _resetDocument,
      variables: {'resetToken': resetToken, 'newPassword': newPassword},
      parserFn: (json) => (json['resetPassword'] as Map<String, dynamic>)['success'] as bool? ?? false,
    ));
    return result.flatMap((ok) => ok ? const Right(null) : const Left(ServerFailure('Password was not changed.')));
  }
}
