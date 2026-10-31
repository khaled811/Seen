// Changing the e-mail against the contract: the documents are validated against
// `docs/api/mobile-api-reference.md`, and the server's codes become issues.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/auth/data/datasources/email_change_remote_data_source.dart';
import 'package:seen_booking/features/auth/domain/entities/email_change.dart';

import '../../../support/scripted_graphql_service.dart';

void main() {
  test('reads the current e-mail from `me`', () async {
    final source = EmailChangeRemoteDataSource(
      graphQLService: ScriptedGraphQLService({
        'MyEmail': {
          'me': {'email': 'owner@agency.com'},
        },
      }),
      language: AppLanguage('ar'),
    );
    expect((await source.currentEmail()), const Right<Failure, String>('owner@agency.com'));
  });

  test('the request carries the new address, the password and the app language', () async {
    final graphql = ScriptedGraphQLService({
      'RequestEmailChange': {'requestEmailChange': true},
    });
    final ar = EmailChangeRemoteDataSource(graphQLService: graphql, language: AppLanguage('ar'));
    final en = EmailChangeRemoteDataSource(graphQLService: graphql, language: AppLanguage('en'));
    expect((await ar.request(newEmail: 'new@agency.com', currentPassword: 'p')).isRight(), isTrue);
    expect((await en.request(newEmail: 'new@agency.com', currentPassword: 'p')).isRight(), isTrue);
    final sent = graphql.where('RequestEmailChange');
    expect(sent.first.variables, {'newEmail': 'new@agency.com', 'currentPassword': 'p', 'locale': 'ar'});
    expect(sent.last.variables['locale'], 'en');
  });

  test('a false answer is a send failure, not a success', () async {
    final source = EmailChangeRemoteDataSource(
      graphQLService: ScriptedGraphQLService({
        'RequestEmailChange': {'requestEmailChange': false},
      }),
      language: AppLanguage('ar'),
    );
    final result = await source.request(newEmail: 'a@b.co', currentPassword: 'p');
    expect(EmailChangeIssue.from((result as Left).value as Failure).kind, EmailChangeIssueKind.sendFailed);
  });

  test('server codes become issues', () {
    EmailChangeIssue issue(Failure f) => EmailChangeIssue.from(f);
    expect(issue(const ServerFailure('x', code: 'current_password_invalid')).kind, EmailChangeIssueKind.wrongPassword);
    expect(issue(const ServerFailure('x', code: 'email_invalid')).kind, EmailChangeIssueKind.invalidEmail);
    expect(issue(const ServerFailure('x', code: 'email_send_failed')).kind, EmailChangeIssueKind.sendFailed);
    final locked = issue(const ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 10}));
    expect((locked.kind, locked.minutes), (EmailChangeIssueKind.rateLimited, 10));
    expect(issue(const NetworkFailure('x')).kind, EmailChangeIssueKind.offline);
    expect(issue(const ServerFailure('x', code: 'new_code')).kind, EmailChangeIssueKind.generic);
  });

  test('isValidEmail accepts a normal address and refuses the rest', () {
    expect(EmailChangeIssue.isValidEmail(' name@mail.com '), isTrue);
    expect(EmailChangeIssue.isValidEmail('name@mail'), isFalse);
    expect(EmailChangeIssue.isValidEmail('name mail@x.com'), isFalse);
    expect(EmailChangeIssue.isValidEmail(''), isFalse);
  });
}
