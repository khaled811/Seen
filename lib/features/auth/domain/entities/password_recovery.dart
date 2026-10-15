import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// A pending "forgot password" attempt: where the code went and when it can be
/// asked for again. Pure Dart.
class RecoveryChallenge extends Equatable {
  const RecoveryChallenge({
    required this.challengeToken,
    required this.maskedDestination,
    required this.resendCooldownSeconds,
  });

  final String challengeToken;

  /// Phone or email with the middle hidden, as returned by the backend.
  final String maskedDestination;
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [challengeToken, maskedDestination, resendCooldownSeconds];
}

/// What went wrong in the recovery flow, in the vocabulary of Figma
/// AUTH-01b / 02b / 03. Built from a [Failure] by [RecoveryIssue.from].
enum RecoveryIssueKind {
  unknownAccount,
  rateLimited,
  offline,
  wrongCode,
  expiredCode,
  attemptsExhausted,
  passwordReused,
  weakPassword,
  generic,
}

class RecoveryIssue extends Equatable {
  const RecoveryIssue(this.kind, {this.seconds, this.attemptsLeft, this.minutes});

  final RecoveryIssueKind kind;

  /// `rateLimited`: seconds until a new code may be requested.
  final int? seconds;

  /// `wrongCode`: tries remaining.
  final int? attemptsLeft;

  /// `attemptsExhausted`: lockout length.
  final int? minutes;

  /// Backend error codes (GraphQL `extensions.code`) this mapping expects.
  /// TODO(backend-contract): confirm the names; see docs/BACKEND_MIGRATION_GAPS.md.
  static const accountNotFound = 'ACCOUNT_NOT_FOUND';
  static const rateLimitedCode = 'RATE_LIMITED';
  static const wrongCodeCode = 'OTP_INVALID';
  static const expiredCodeCode = 'OTP_EXPIRED';
  static const exhaustedCode = 'OTP_ATTEMPTS_EXHAUSTED';
  static const passwordReusedCode = 'PASSWORD_REUSED';
  static const weakPasswordCode = 'PASSWORD_WEAK';

  factory RecoveryIssue.from(Failure failure) {
    if (failure is NetworkFailure) return const RecoveryIssue(RecoveryIssueKind.offline);
    if (failure is ServerFailure) {
      int? number(String key) {
        final v = failure.details[key];
        return v is num ? v.toInt() : int.tryParse('$v');
      }

      return switch (failure.code) {
        accountNotFound => const RecoveryIssue(RecoveryIssueKind.unknownAccount),
        rateLimitedCode => RecoveryIssue(RecoveryIssueKind.rateLimited, seconds: number('retryAfterSeconds')),
        wrongCodeCode => RecoveryIssue(RecoveryIssueKind.wrongCode, attemptsLeft: number('attemptsLeft')),
        expiredCodeCode => const RecoveryIssue(RecoveryIssueKind.expiredCode),
        exhaustedCode => RecoveryIssue(RecoveryIssueKind.attemptsExhausted, minutes: number('lockoutMinutes')),
        passwordReusedCode => const RecoveryIssue(RecoveryIssueKind.passwordReused),
        weakPasswordCode => const RecoveryIssue(RecoveryIssueKind.weakPassword),
        _ => const RecoveryIssue(RecoveryIssueKind.generic),
      };
    }
    return const RecoveryIssue(RecoveryIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, seconds, attemptsLeft, minutes];
}
