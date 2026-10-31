import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

enum EmailChangeIssueKind { invalidEmail, sameAsCurrent, wrongPassword, rateLimited, sendFailed, offline, generic }

class EmailChangeIssue extends Equatable {
  const EmailChangeIssue(this.kind, {this.minutes});

  final EmailChangeIssueKind kind;

  /// Minutes until the next try (`too_many_attempts`).
  final int? minutes;

  /// Codes of the contract (reference, "Error codes").
  static const wrongPasswordCode = 'current_password_invalid';
  static const invalidEmailCode = 'email_invalid';
  static const sendFailedCode = 'email_send_failed';
  static const rateLimitedCode = 'too_many_attempts';

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  factory EmailChangeIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const EmailChangeIssue(EmailChangeIssueKind.offline);
    }
    if (failure is ServerFailure) {
      final raw = failure.details['minutes'];
      final minutes = raw is num ? raw.toInt() : int.tryParse('$raw');
      return switch (failure.code) {
        wrongPasswordCode => const EmailChangeIssue(EmailChangeIssueKind.wrongPassword),
        invalidEmailCode => const EmailChangeIssue(EmailChangeIssueKind.invalidEmail),
        sendFailedCode => const EmailChangeIssue(EmailChangeIssueKind.sendFailed),
        rateLimitedCode => EmailChangeIssue(EmailChangeIssueKind.rateLimited, minutes: minutes),
        _ => const EmailChangeIssue(EmailChangeIssueKind.generic),
      };
    }
    return const EmailChangeIssue(EmailChangeIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, minutes];
}
