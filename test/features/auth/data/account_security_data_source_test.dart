// Changing the password and reading the phone against the contract, and what
// happens after a password change (the server signs every session out).

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/auth/data/datasources/account_security_remote_data_source.dart';
import 'package:seen_booking/features/auth/domain/repositories/account_security_repository.dart';
import 'package:seen_booking/features/auth/presentation/bloc/account_security_cubits.dart';

import '../../../support/scripted_graphql_service.dart';

void main() {
  group('changeMyPassword', () {
    test('sends the current and the new password; true is success', () async {
      final graphql = ScriptedGraphQLService({
        'ChangeMyPassword': {'changeMyPassword': true},
      });
      final source = AccountSecurityRemoteDataSource(graphQLService: graphql);
      expect((await source.changePassword(current: 'old-password-1', next: 'new-password-123')).isRight(), isTrue);
      expect(graphql.where('ChangeMyPassword').single.variables, {'current': 'old-password-1', 'next': 'new-password-123'});
    });

    test('false is never shown as success; a refusal keeps its code', () async {
      final no = AccountSecurityRemoteDataSource(
        graphQLService: ScriptedGraphQLService({
          'ChangeMyPassword': {'changeMyPassword': false},
        }),
      );
      expect((await no.changePassword(current: 'a', next: 'b')).isLeft(), isTrue);

      final refused = AccountSecurityRemoteDataSource(
        graphQLService: ScriptedGraphQLService({'ChangeMyPassword': const ServerFailure('x', code: 'current_password_invalid')}),
      );
      final failure = ((await refused.changePassword(current: 'a', next: 'b')) as Left).value as ServerFailure;
      expect(failure.code, 'current_password_invalid');
    });
  });

  group('the current phone', () {
    test('is read from me.phone and shown with its middle hidden', () async {
      final graphql = ScriptedGraphQLService({
        'MyPhone': {
          'me': {'phone': '+967771230700'},
        },
      });
      final source = AccountSecurityRemoteDataSource(graphQLService: graphql);
      expect(((await source.currentPhoneMasked()) as Right).value, '+••• 0700');
    });

    test('masking keeps only the last four digits', () {
      expect(AccountSecurityRemoteDataSource.maskPhone('+967 77 123 0700'), '+••• 0700');
      expect(AccountSecurityRemoteDataSource.maskPhone('0771230700'), '••• 0700');
      expect(AccountSecurityRemoteDataSource.maskPhone('123'), '•••');
      expect(AccountSecurityRemoteDataSource.maskPhone(''), '');
    });
  });

  test('a phone change with a code has no operation: it fails without a call', () async {
    final graphql = ScriptedGraphQLService(const {});
    final source = AccountSecurityRemoteDataSource(graphQLService: graphql);
    for (final result in [
      await source.requestPhoneChange('+967771230700'),
      await source.resendPhoneChange('t'),
      await source.confirmPhoneChange(challengeToken: 't', code: '123456'),
    ]) {
      expect(((result as Left).value as ServerFailure).code, 'unsupported_operation');
    }
    expect(graphql.sent, isEmpty);
  });

  group('ChangePasswordCubit', () {
    test('after a change the app ends its own session too (the server ended every one)', () async {
      var ended = 0;
      final cubit = ChangePasswordCubit(_Repo(const Right(null)), onChanged: () => ended++);
      await cubit.submit(current: 'a', next: 'b');
      expect(cubit.state.done, isTrue);
      expect(ended, 1);
      await cubit.close();
    });

    test('a refused change keeps the session', () async {
      var ended = 0;
      final cubit = ChangePasswordCubit(
        _Repo(const Left(ServerFailure('x', code: 'current_password_invalid'))),
        onChanged: () => ended++,
      );
      await cubit.submit(current: 'a', next: 'b');
      expect(cubit.state.done, isFalse);
      expect(cubit.state.issue, isNotNull);
      expect(ended, 0);
      await cubit.close();
    });
  });
}

class _Repo implements AccountSecurityRepository {
  _Repo(this.result);

  final Either<Failure, void> result;

  @override
  Future<Either<Failure, void>> changePassword({required String current, required String next}) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
