// The server names the rule a refused password broke (`params.rule` of `password_weak`);
// every place that sets a password shows that rule, and the general text otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/error/password_rule.dart';
import 'package:seen_booking/core/presentation/failure_message.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';
import 'package:seen_booking/features/auth/domain/entities/account_security.dart';
import 'package:seen_booking/features/auth/domain/entities/agency_registration.dart';

ServerFailure _weak([String? rule]) => ServerFailure('x', code: 'password_weak', details: {if (rule != null) 'rule': rule});

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('passwordRuleOf reads the rule only from a password_weak failure', () {
    expect(passwordRuleOf(_weak('password_too_short')), 'password_too_short');
    expect(passwordRuleOf(_weak()), isNull);
    expect(passwordRuleOf(const ServerFailure('x', code: 'other', details: {'rule': 'password_too_short'})), isNull);
    expect(passwordRuleOf(const NetworkFailure('x')), isNull);
  });

  test('each rule has its own text; an unknown or missing one gets the general text', () {
    final texts = {
      for (final r in ['password_too_similar', 'password_too_short', 'password_too_common', 'password_entirely_numeric']) r: passwordRuleMessage(ar, r),
    };
    expect(texts.values.toSet().length, 4); // four different messages
    expect(texts['password_too_short'], ar.passwordRuleShort);
    expect(passwordRuleMessage(ar, 'something_new'), ar.recoveryPasswordWeak);
    expect(passwordRuleMessage(ar, null), ar.recoveryPasswordWeak);
  });

  test('the generic failure text resolver uses the rule too', () {
    expect(localizedFailureMessage(ar, _weak('password_too_common')), ar.passwordRuleCommon);
    expect(localizedFailureMessage(ar, _weak()), ar.recoveryPasswordWeak);
  });

  test('registration, change-password and add-agent issues carry the rule', () {
    expect(RegistrationIssue.from(_weak('password_too_similar')).passwordRule, 'password_too_similar');
    expect(AccountIssue.from(_weak('password_too_short')).passwordRule, 'password_too_short');
    final sub = SubAgentIssue.from(_weak('password_entirely_numeric'));
    expect((sub.kind, sub.passwordRule), (SubAgentIssueKind.weakPassword, 'password_entirely_numeric'));
  });
}
