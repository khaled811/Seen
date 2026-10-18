import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/account_security.dart';
import '../../domain/repositories/account_security_repository.dart';

/// Raw GraphQL access for changing the password and the phone number.
///
/// TODO(backend-contract): placeholder schema (`changePassword`, `me { maskedPhone }`,
/// `requestPhoneChange`, `resendPhoneChange`, `confirmPhoneChange`); see
/// docs/BACKEND_MIGRATION_GAPS.md section 39.
class AccountSecurityRemoteDataSource implements AccountSecurityRepository {
  AccountSecurityRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static const _challengeFields = 'challengeToken resendCooldownSeconds';

  static final _changePasswordDoc = gql(r'''
    mutation ChangePassword($current: String!, $next: String!) {
      changePassword(currentPassword: $current, newPassword: $next) { success }
    }
  ''');

  static final _maskedPhoneDoc = gql(r'''
    query MyPhone { me { maskedPhone } }
  ''');

  static final _requestDoc = gql('''
    mutation RequestPhoneChange(\$phone: String!) {
      requestPhoneChange(newPhone: \$phone) { $_challengeFields }
    }
  ''');

  static final _resendDoc = gql('''
    mutation ResendPhoneChange(\$token: String!) {
      resendPhoneChange(challengeToken: \$token) { $_challengeFields }
    }
  ''');

  static final _confirmDoc = gql(r'''
    mutation ConfirmPhoneChange($token: String!, $code: String!) {
      confirmPhoneChange(challengeToken: $token, code: $code) { success }
    }
  ''');

  static PhoneChangeChallenge _challenge(Object? json) {
    final m = json as Map<String, dynamic>;
    return PhoneChangeChallenge(
      challengeToken: m['challengeToken'] as String,
      resendCooldownSeconds: (m['resendCooldownSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<Either<Failure, void>> changePassword({required String current, required String next}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _changePasswordDoc,
        variables: {'current': current, 'next': next},
        parserFn: (j) => (j['changePassword'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
      )))
          .map((_) {});

  @override
  Future<Either<Failure, String>> currentPhoneMasked() => _graphQL.query<String>(QueryOptions<String>(
        document: _maskedPhoneDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => ((j['me'] as Map<String, dynamic>)['maskedPhone'] as String?) ?? '',
      ));

  @override
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone) =>
      _graphQL.mutate<PhoneChangeChallenge>(MutationOptions<PhoneChangeChallenge>(
        document: _requestDoc,
        variables: {'phone': newPhone},
        parserFn: (j) => _challenge(j['requestPhoneChange']),
      ));

  @override
  Future<Either<Failure, PhoneChangeChallenge>> resendPhoneChange(String challengeToken) =>
      _graphQL.mutate<PhoneChangeChallenge>(MutationOptions<PhoneChangeChallenge>(
        document: _resendDoc,
        variables: {'token': challengeToken},
        parserFn: (j) => _challenge(j['resendPhoneChange']),
      ));

  @override
  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _confirmDoc,
        variables: {'token': challengeToken, 'code': code},
        parserFn: (j) => (j['confirmPhoneChange'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
      )))
          .map((_) {});
}

/// DEBUG ONLY: when a real call fails in a debug build, answers with canned results so
/// both flows and their error states can be tried before the backend exists.
/// Demo rules: the current password `Old@12345` is wrong; a new password `Used@12345` was
/// used before; a new number ending in `0711` is taken; code `123456` is right, `000000`
/// expired, anything else wrong (3 tries, then locked). `kDebugMode` is a compile-time constant,
/// so release builds drop every branch.
class DebugFallbackAccountSecurityRepository implements AccountSecurityRepository {
  DebugFallbackAccountSecurityRepository(this._real);

  final AccountSecurityRepository _real;
  int _triesLeft = 3;

  @override
  Future<Either<Failure, void>> changePassword({required String current, required String next}) async {
    final r = await _real.changePassword(current: current, next: next);
    if (kDebugMode && r.isLeft()) {
      if (current == 'Old@12345') {
        return const Left(ServerFailure('wrong', code: AccountIssue.wrongCurrentPasswordCode));
      }
      if (next == 'Used@12345') {
        return const Left(ServerFailure('reused', code: AccountIssue.passwordReusedCode));
      }
      return const Right(null);
    }
    return r;
  }

  @override
  Future<Either<Failure, String>> currentPhoneMasked() async {
    final r = await _real.currentPhoneMasked();
    if (kDebugMode && r.isLeft()) {
      return const Right('+967 77 ••• 0700');
    }
    return r;
  }

  @override
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone) async {
    final r = await _real.requestPhoneChange(newPhone);
    if (kDebugMode && r.isLeft()) {
      if (newPhone.endsWith('0711')) {
        return const Left(ServerFailure('taken', code: AccountIssue.phoneTakenCode));
      }
      _triesLeft = 3;
      return const Right(PhoneChangeChallenge(challengeToken: 'debug-phone', resendCooldownSeconds: 45));
    }
    return r;
  }

  @override
  Future<Either<Failure, PhoneChangeChallenge>> resendPhoneChange(String challengeToken) async {
    final r = await _real.resendPhoneChange(challengeToken);
    if (kDebugMode && r.isLeft()) {
      return const Right(PhoneChangeChallenge(challengeToken: 'debug-phone', resendCooldownSeconds: 45));
    }
    return r;
  }

  @override
  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code}) async {
    final r = await _real.confirmPhoneChange(challengeToken: challengeToken, code: code);
    if (kDebugMode && r.isLeft()) {
      if (code == '123456') {
        return const Right(null);
      }
      if (code == '000000') {
        return const Left(ServerFailure('expired', code: AccountIssue.expiredCodeCode));
      }
      _triesLeft--;
      return _triesLeft > 0
          ? Left(ServerFailure('wrong', code: AccountIssue.wrongCodeCode, details: {'attemptsLeft': _triesLeft}))
          : const Left(ServerFailure('locked', code: AccountIssue.exhaustedCode, details: {'lockoutMinutes': 15}));
    }
    return r;
  }
}
