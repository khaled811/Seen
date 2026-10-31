// The contract validator itself, and the auth documents checked against the
// backend contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:seen_booking/features/auth/data/datasources/auth_remote_data_source.dart';

import '../../support/contract_schema.dart';
import '../../support/scripted_graphql_service.dart';

List<String> _check(String document) => ContractSchema.load().validate(gql(document));

void main() {
  group('ContractSchema', () {
    test('reads operations and types from the reference', () {
      final schema = ContractSchema.load();
      expect(schema.mutations.keys, containsAll(['login', 'verifyOtp', 'refresh', 'logout', 'submitTopUp']));
      expect(schema.queries.keys, containsAll(['me', 'portalWallet', 'portalRequests']));
      expect(schema.mutations['login']!.args['enrollmentLink']!.hasDefault, isTrue);
      expect(schema.types['AuthResult']!['accessToken']!.type, 'String');
      expect(schema.types['Wallet']!['transactions']!.args.keys, containsAll(['limit', 'offset']));
    });

    test('accepts a correct document', () {
      expect(
        _check(r'mutation L($email: String!, $password: String!) { login(email: $email, password: $password) { accessToken otpRequired } }'),
        isEmpty,
      );
    });

    test('rejects an operation that does not exist', () {
      expect(_check('mutation X { resendOtp(challengeToken: "a") { challengeToken } }'), isNotEmpty);
    });

    test('rejects an unknown argument and a missing required one', () {
      final problems = _check(r'mutation L($e: String!) { login(identifier: $e) { accessToken } }');
      expect(problems.join(), contains('argument "identifier" does not exist'));
      expect(problems.join(), contains('required argument "email" is missing'));
    });

    test('rejects a variable type that does not match (String where the contract says Decimal)', () {
      final problems = _check(
        r'mutation T($a: String!, $m: String!) { requestTopUp(amount: $a, method: $m) { id } }',
      );
      expect(problems.join(), contains('Decimal'));
    });

    test('rejects a selection on a scalar and a missing selection on an object', () {
      expect(_check('mutation M { logout { success } }').join(), contains('scalar'));
      expect(_check('query Q { me }').join(), contains('needs a selection set'));
    });

    test('rejects a field the type does not have', () {
      expect(_check('query Q { me { id nickname } }').join(), contains('no field "nickname"'));
    });
  });

  group('auth documents match the contract', () {
    test('login, verifyOtp and me', () async {
      final service = ScriptedGraphQLService({
        'Login': {
          'login': {'accessToken': 'a', 'otpRequired': false}
        },
        'VerifyOtp': {
          'verifyOtp': {'accessToken': 'a'}
        },
        'Me': {
          'me': {
            'id': 'u1',
            'userType': 'agent',
            'agentPosition': 'owner',
            'permissions': ['request.submit'],
            'agent': {'id': 'a1', 'status': 'active'},
          }
        },
      });
      final remote = AuthRemoteDataSourceImpl(graphQLService: service);

      expect((await remote.login(email: 'a@b.test', password: 'pw')).isRight(), isTrue);
      expect((await remote.verifyOtp(challengeId: 'c', code: '123456')).isRight(), isTrue);
      expect((await remote.me()).isRight(), isTrue);

      expect(service.where('Login').single.variables, {'email': 'a@b.test', 'password': 'pw'});
      expect(service.where('VerifyOtp').single.variables, {'challengeId': 'c', 'code': '123456'});
    });
  });
}
