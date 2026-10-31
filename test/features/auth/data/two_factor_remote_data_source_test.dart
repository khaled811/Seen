// Two-step verification against the contract: every document is validated against
// `docs/api/mobile-api-reference.md`, and the answers are read the way the server sends them.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/auth/data/datasources/two_factor_remote_data_source.dart';
import 'package:seen_booking/features/auth/domain/entities/two_factor.dart';

import '../../../support/scripted_graphql_service.dart';

void main() {
  test('status reads the three flags of `me`; either flag means it is on', () async {
    final source = TwoFactorRemoteDataSource(
      graphQLService: ScriptedGraphQLService({
        'TwoFactorStatus': {
          'me': {'otpEnabled': false, 'twoFactorEnrolled': true, 'recoveryCodesRemaining': 8},
        },
      }),
    );
    final status = ((await source.status()) as Right).value as TwoFactorStatus;
    expect((status.enabled, status.enrolled, status.recoveryCodesLeft), (false, true, 8));
    expect(status.isOn, isTrue);
  });

  test('begin returns the secret and the otpauth link, grouped in fours for typing', () async {
    final source = TwoFactorRemoteDataSource(
      graphQLService: ScriptedGraphQLService({
        'BeginOtpEnrollment': {
          'beginOtpEnrollment': {'secret': 'JBSWY3DPEHPK3PXP', 'provisioningUri': 'otpauth://totp/Seen?secret=JBSWY3DPEHPK3PXP'},
        },
      }),
    );
    final setup = ((await source.begin()) as Right).value as TwoFactorSetup;
    expect(setup.provisioningUri, startsWith('otpauth://'));
    expect(setup.groupedSecret, 'JBSW Y3DP EHPK 3PXP');
  });

  test('confirm and regenerate send the code and return the recovery codes', () async {
    final graphql = ScriptedGraphQLService({
      'ConfirmOtpEnrollment': {
        'confirmOtpEnrollment': {'codes': ['A-1', 'A-2']},
      },
      'RegenerateRecoveryCodes': {
        'regenerateRecoveryCodes': {'codes': ['B-1']},
      },
    });
    final source = TwoFactorRemoteDataSource(graphQLService: graphql);
    expect(((await source.confirm('123456')) as Right).value, ['A-1', 'A-2']);
    expect(((await source.regenerateRecoveryCodes('654321')) as Right).value, ['B-1']);
    expect(graphql.where('ConfirmOtpEnrollment').single.variables, {'code': '123456'});
    expect(graphql.where('RegenerateRecoveryCodes').single.variables, {'code': '654321'});
  });

  test('server codes become issues: wrong code, lock with minutes, not enrolled, offline', () {
    TwoFactorIssue issue(Failure f) => TwoFactorIssue.from(f);
    expect(issue(const ServerFailure('x', code: 'otp_code_invalid')).kind, TwoFactorIssueKind.wrongCode);
    final locked = issue(const ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 15}));
    expect((locked.kind, locked.minutes), (TwoFactorIssueKind.rateLimited, 15));
    expect(issue(const ServerFailure('x', code: 'otp_not_enrolled')).kind, TwoFactorIssueKind.notEnrolled);
    expect(issue(const ServerFailure('x', code: 'otp_not_enrolling')).kind, TwoFactorIssueKind.notEnrolling);
    expect(issue(const NetworkFailure('x')).kind, TwoFactorIssueKind.offline);
    expect(issue(const ServerFailure('x', code: 'something_new')).kind, TwoFactorIssueKind.generic);
  });
}
