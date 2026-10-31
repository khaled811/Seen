import '../../../../core/error/password_rule.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// A pending "change my phone number" attempt: where the code went and when it can be
/// asked for again (Figma AUTH-16). Pure Dart.
class PhoneChangeChallenge extends Equatable {
  const PhoneChangeChallenge({required this.challengeToken, required this.resendCooldownSeconds});

  final String challengeToken;
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [challengeToken, resendCooldownSeconds];
}

/// What went wrong in the change-password / change-phone flows (Figma AUTH-15 / 16),
/// built from a [Failure] by [AccountIssue.from].
enum AccountIssueKind {
  wrongCurrentPassword,
  passwordReused,
  weakPassword,
  phoneTaken,
  wrongCode,
  expiredCode,
  attemptsExhausted,
  rateLimited,
  offline,
  generic,
}

class AccountIssue extends Equatable {
  const AccountIssue(this.kind, {this.attemptsLeft, this.seconds, this.minutes, this.passwordRule});

  final AccountIssueKind kind;
  final int? attemptsLeft;
  final int? seconds;
  final int? minutes;

  /// The password rule the server named (`weakPassword` only).
  final String? passwordRule;

  /// Error codes of the contract (reference, "Error codes"). The phone-change
  /// ones are not in the contract (the flow is unsupported); they stay for the
  /// debug fallback's demo only.
  static const wrongCurrentPasswordCode = 'current_password_invalid';
  static const passwordReusedCode = 'password_unchanged';
  static const weakPasswordCode = 'password_weak';
  static const phoneTakenCode = 'PHONE_ALREADY_REGISTERED';
  static const wrongCodeCode = 'OTP_INVALID';
  static const expiredCodeCode = 'OTP_EXPIRED';
  static const exhaustedCode = 'OTP_ATTEMPTS_EXHAUSTED';
  static const rateLimitedCode = 'too_many_attempts';

  factory AccountIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const AccountIssue(AccountIssueKind.offline);
    }
    if (failure is ServerFailure) {
      int? number(String key) {
        final v = failure.details[key];
        return v is num ? v.toInt() : int.tryParse('$v');
      }

      return switch (failure.code) {
        wrongCurrentPasswordCode => const AccountIssue(AccountIssueKind.wrongCurrentPassword),
        passwordReusedCode => const AccountIssue(AccountIssueKind.passwordReused),
        weakPasswordCode => AccountIssue(AccountIssueKind.weakPassword, passwordRule: passwordRuleOf(failure)),
        phoneTakenCode => const AccountIssue(AccountIssueKind.phoneTaken),
        wrongCodeCode => AccountIssue(AccountIssueKind.wrongCode, attemptsLeft: number('attemptsLeft')),
        expiredCodeCode => const AccountIssue(AccountIssueKind.expiredCode),
        exhaustedCode => AccountIssue(AccountIssueKind.attemptsExhausted, minutes: number('lockoutMinutes')),
        rateLimitedCode => AccountIssue(AccountIssueKind.rateLimited, seconds: number('retryAfterSeconds'), minutes: number('minutes')),
        _ => const AccountIssue(AccountIssueKind.generic),
      };
    }
    return const AccountIssue(AccountIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, attemptsLeft, seconds, minutes];
}
