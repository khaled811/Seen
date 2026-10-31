import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/auth_payload_dto.dart';
import '../models/me_dto.dart';

/// Raw GraphQL access for sign-in (`docs/api/mobile-api.md` section 3). Returns
/// DTOs, never entities: mapping to domain happens in `AuthRepositoryImpl`.
///
/// `refresh` and `logout` are not here: they are session operations owned by
/// the transport (`SessionRemoteDataSource`), because they need the cookie.
abstract interface class AuthRemoteDataSource {
  Future<Either<Failure, AuthPayloadDto>> login({required String email, required String password});

  /// [code] is the 6-digit authenticator code or a single-use recovery code
  /// (`xxxx-xxxx-xxxx`); the server accepts both in the same argument.
  Future<Either<Failure, AuthPayloadDto>> verifyOtp({required String challengeId, required String code});

  Future<Either<Failure, MeDto>> me();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required GraphQLService graphQLService}) : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  // Only what the app uses. The enrollment token and recovery codes are
  // deliberately not requested: enrollment happens on the web (the e-mailed
  // link opens a web page), so the app never needs those secrets.
  static final _loginDocument = gql(r'''
    mutation Login($email: String!, $password: String!) {
      login(email: $email, password: $password) {
        accessToken
        otpRequired
        challengeId
        enrollmentRequired
        enrollmentCodeRequired
      }
    }
  ''');

  static final _verifyOtpDocument = gql(r'''
    mutation VerifyOtp($challengeId: String!, $code: String!) {
      verifyOtp(challengeId: $challengeId, code: $code) {
        accessToken
        otpRequired
        challengeId
        enrollmentRequired
        enrollmentCodeRequired
      }
    }
  ''');

  static final _meDocument = gql(r'''
    query Me {
      me {
        id
        userType
        agentPosition
        permissions
        agent {
          id
          status
        }
      }
    }
  ''');

  @override
  Future<Either<Failure, AuthPayloadDto>> login({required String email, required String password}) {
    return _graphQLService.mutate<AuthPayloadDto>(
      MutationOptions<AuthPayloadDto>(
        document: _loginDocument,
        variables: {'email': email, 'password': password},
        parserFn: (json) => AuthPayloadDto.fromJson(json['login'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, AuthPayloadDto>> verifyOtp({required String challengeId, required String code}) {
    return _graphQLService.mutate<AuthPayloadDto>(
      MutationOptions<AuthPayloadDto>(
        document: _verifyOtpDocument,
        variables: {'challengeId': challengeId, 'code': code},
        parserFn: (json) => AuthPayloadDto.fromJson(json['verifyOtp'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, MeDto>> me() {
    return _graphQLService.query<MeDto>(
      QueryOptions<MeDto>(
        document: _meDocument,
        parserFn: (json) => MeDto.fromJson(json['me'] as Map<String, dynamic>),
      ),
    );
  }
}
