import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/account_security.dart';
import '../../domain/repositories/account_security_repository.dart';

/// The signed-in user's own credentials against the contract.
///
/// - `changeMyPassword(currentPassword, newPassword)` is real; the server signs
///   every session out afterwards (the cubit ends this one too).
/// - The current number comes from `me { phone }` and is masked here.
/// - A phone change with a code has no operation (`updateMyProfile` sets a number
///   without any verification, which the flow's design cannot honour), so those
///   three calls are `unsupported_operation` (DECISIONS P-03).
class AccountSecurityRemoteDataSource implements AccountSecurityRepository {
  AccountSecurityRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _changePasswordDoc = gql(r'''
    mutation ChangeMyPassword($current: String!, $next: String!) {
      changeMyPassword(currentPassword: $current, newPassword: $next)
    }
  ''');

  static final _phoneDoc = gql(r'''
    query MyPhone { me { phone } }
  ''');

  /// `+967 77 ••• 0700`-style: the number with its middle hidden.
  static String maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return phone.isEmpty ? '' : '•••';
    final tail = digits.substring(digits.length - 4);
    return '${phone.trim().startsWith('+') ? '+' : ''}••• $tail';
  }

  @override
  Future<Either<Failure, void>> changePassword({required String current, required String next}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _changePasswordDoc,
        variables: {'current': current, 'next': next},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['changeMyPassword'] == true,
      )))
          .flatMap((changed) => changed ? const Right(null) : const Left(ServerFailure('The password was not changed.')));

  @override
  Future<Either<Failure, String>> currentPhoneMasked() => _graphQL.query<String>(QueryOptions<String>(
        document: _phoneDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => maskPhone(((j['me'] as Map<String, dynamic>)['phone'] as String?) ?? ''),
      ));

  @override
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone) async =>
      unsupportedOperation('Changing the phone number with a code');

  @override
  Future<Either<Failure, PhoneChangeChallenge>> resendPhoneChange(String challengeToken) async =>
      unsupportedOperation('Resending a phone-change code');

  @override
  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code}) async =>
      unsupportedOperation('Confirming a phone change');
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
    if (debugFallbacksEnabled && r.isLeft()) {
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
    if (debugFallbacksEnabled && r.isLeft()) {
      return const Right('+967 77 ••• 0700');
    }
    return r;
  }

  @override
  Future<Either<Failure, PhoneChangeChallenge>> requestPhoneChange(String newPhone) async {
    final r = await _real.requestPhoneChange(newPhone);
    if (debugFallbacksEnabled && r.isLeft()) {
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
    if (debugFallbacksEnabled && r.isLeft()) {
      return const Right(PhoneChangeChallenge(challengeToken: 'debug-phone', resendCooldownSeconds: 45));
    }
    return r;
  }

  @override
  Future<Either<Failure, void>> confirmPhoneChange({required String challengeToken, required String code}) async {
    final r = await _real.confirmPhoneChange(challengeToken: challengeToken, code: code);
    if (debugFallbacksEnabled && r.isLeft()) {
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
