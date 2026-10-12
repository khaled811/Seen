import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/auth_payload_dto.dart';
import '../models/otp_challenge_dto.dart';

/// Raw GraphQL access for the auth feature. Returns DTOs, never entities —
/// mapping to domain happens in `AuthRepositoryImpl`.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (mutation names `login`/`verifyOtp`/`resendOtp`, argument names, and
/// response fields). Update once the real Seen Booking GraphQL schema is
/// confirmed — see the matching TODO in `auth_payload_dto.dart`.
abstract interface class AuthRemoteDataSource {
  Future<Either<Failure, AuthPayloadDto>> login({
    required String identifier,
    required String password,
  });

  Future<Either<Failure, AuthPayloadDto>> verifyOtp({
    required String challengeToken,
    required String code,
  });

  Future<Either<Failure, OtpChallengeDto>> resendOtp({
    required String challengeToken,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _userFields = r'''
    user {
      id
      userType
      position
      branchId
      permissionCodes
    }
  ''';

  static final _loginDocument = gql('''
    mutation Login(\$identifier: String!, \$password: String!) {
      login(identifier: \$identifier, password: \$password) {
        requiresOtp
        challengeToken
        resendCooldownSeconds
        accessToken
        $_userFields
      }
    }
  ''');

  static final _verifyOtpDocument = gql('''
    mutation VerifyOtp(\$challengeToken: String!, \$code: String!) {
      verifyOtp(challengeToken: \$challengeToken, code: \$code) {
        requiresOtp
        accessToken
        $_userFields
      }
    }
  ''');

  static final _resendOtpDocument = gql(r'''
    mutation ResendOtp($challengeToken: String!) {
      resendOtp(challengeToken: $challengeToken) {
        challengeToken
        resendCooldownSeconds
      }
    }
  ''');

  @override
  Future<Either<Failure, AuthPayloadDto>> login({
    required String identifier,
    required String password,
  }) {
    return _graphQLService.mutate<AuthPayloadDto>(
      MutationOptions<AuthPayloadDto>(
        document: _loginDocument,
        variables: {'identifier': identifier, 'password': password},
        parserFn: (json) =>
            AuthPayloadDto.fromJson(json['login'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, AuthPayloadDto>> verifyOtp({
    required String challengeToken,
    required String code,
  }) {
    return _graphQLService.mutate<AuthPayloadDto>(
      MutationOptions<AuthPayloadDto>(
        document: _verifyOtpDocument,
        variables: {'challengeToken': challengeToken, 'code': code},
        parserFn: (json) =>
            AuthPayloadDto.fromJson(json['verifyOtp'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, OtpChallengeDto>> resendOtp({
    required String challengeToken,
  }) {
    return _graphQLService.mutate<OtpChallengeDto>(
      MutationOptions<OtpChallengeDto>(
        document: _resendOtpDocument,
        variables: {'challengeToken': challengeToken},
        parserFn: (json) => OtpChallengeDto.fromJson(
          json['resendOtp'] as Map<String, dynamic>,
        ),
      ),
    );
  }
}
