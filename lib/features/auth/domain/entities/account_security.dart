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
  const AccountIssue(this.kind, {this.attemptsLeft, this.seconds, this.minutes});

  final AccountIssueKind kind;
  final int? attemptsLeft;
  final int? seconds;
  final int? minutes;

  /// Backend error codes (GraphQL `extensions.code`) this mapping expects.
  /// TODO(backend-contract): confirm the names; see docs/BACKEND_MIGRATION_GAPS.md section 39.
  static const wrongCurrentPasswordCode = 'WRONG_CURRENT_PASSWORD';
  static const passwordReusedCode = 'PASSWORD_REUSED';
  static const weakPasswordCode = 'PASSWORD_WEAK';
  static const phoneTakenCode = 'PHONE_ALREADY_REGISTERED';
  static const wrongCodeCode = 'OTP_INVALID';
  static const expiredCodeCode = 'OTP_EXPIRED';
  static const exhaustedCode = 'OTP_ATTEMPTS_EXHAUSTED';
  static const rateLimitedCode = 'RATE_LIMITED';

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
        weakPasswordCode => const AccountIssue(AccountIssueKind.weakPassword),
        phoneTakenCode => const AccountIssue(AccountIssueKind.phoneTaken),
        wrongCodeCode => AccountIssue(AccountIssueKind.wrongCode, attemptsLeft: number('attemptsLeft')),
        expiredCodeCode => const AccountIssue(AccountIssueKind.expiredCode),
        exhaustedCode => AccountIssue(AccountIssueKind.attemptsExhausted, minutes: number('lockoutMinutes')),
        rateLimitedCode => AccountIssue(AccountIssueKind.rateLimited, seconds: number('retryAfterSeconds')),
        _ => const AccountIssue(AccountIssueKind.generic),
      };
    }
    return const AccountIssue(AccountIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, attemptsLeft, seconds, minutes];
}
