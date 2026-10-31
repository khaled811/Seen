import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/two_factor.dart';
import '../../domain/repositories/two_factor_repository.dart';

/// Two-step verification against the contract: `me` (status), `beginOtpEnrollment`,
/// `confirmOtpEnrollment` and `regenerateRecoveryCodes`.
///
/// The secret and the recovery codes pass through here and are never logged or cached
/// (`FetchPolicy.noCache`).
class TwoFactorRemoteDataSource implements TwoFactorRepository {
  TwoFactorRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _statusDoc = gql(r'''
    query TwoFactorStatus { me { otpEnabled twoFactorEnrolled recoveryCodesRemaining } }
  ''');

  static final _beginDoc = gql(r'''
    mutation BeginOtpEnrollment { beginOtpEnrollment { secret provisioningUri } }
  ''');

  static final _confirmDoc = gql(r'''
    mutation ConfirmOtpEnrollment($code: String!) { confirmOtpEnrollment(code: $code) { codes } }
  ''');

  static final _regenerateDoc = gql(r'''
    mutation RegenerateRecoveryCodes($code: String!) { regenerateRecoveryCodes(code: $code) { codes } }
  ''');

  static List<String> _codes(Map<String, dynamic> json, String field) =>
      [for (final c in (json[field] as Map<String, dynamic>)['codes'] as List<dynamic>) c as String];

  @override
  Future<Either<Failure, TwoFactorStatus>> status() => _graphQL.query<TwoFactorStatus>(QueryOptions<TwoFactorStatus>(
        document: _statusDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) {
          final me = j['me'] as Map<String, dynamic>;
          return TwoFactorStatus(
            enabled: me['otpEnabled'] == true,
            enrolled: me['twoFactorEnrolled'] == true,
            recoveryCodesLeft: (me['recoveryCodesRemaining'] as num?)?.toInt() ?? 0,
          );
        },
      ));

  @override
  Future<Either<Failure, TwoFactorSetup>> begin() => _graphQL.mutate<TwoFactorSetup>(MutationOptions<TwoFactorSetup>(
        document: _beginDoc,
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) {
          final r = j['beginOtpEnrollment'] as Map<String, dynamic>;
          return TwoFactorSetup(secret: r['secret'] as String, provisioningUri: r['provisioningUri'] as String);
        },
      ));

  @override
  Future<Either<Failure, List<String>>> confirm(String code) => _graphQL.mutate<List<String>>(MutationOptions<List<String>>(
        document: _confirmDoc,
        variables: {'code': code},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => _codes(j, 'confirmOtpEnrollment'),
      ));

  @override
  Future<Either<Failure, List<String>>> regenerateRecoveryCodes(String code) =>
      _graphQL.mutate<List<String>>(MutationOptions<List<String>>(
        document: _regenerateDoc,
        variables: {'code': code},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => _codes(j, 'regenerateRecoveryCodes'),
      ));
}
