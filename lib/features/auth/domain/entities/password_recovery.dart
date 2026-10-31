import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// What went wrong in the recovery flow, in the vocabulary of Figma
/// AUTH-01b / 02b / 03. Built from a [Failure] by [RecoveryIssue.from].
enum RecoveryIssueKind {
  rateLimited,
  offline,
  emailRequired,
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

  /// The contract's code for an exceeded throttle (3 per address per hour).
  static const rateLimitedCode = 'too_many_attempts';

  factory RecoveryIssue.from(Failure failure) {
    if (failure is NetworkFailure) return const RecoveryIssue(RecoveryIssueKind.offline);
    if (failure is ServerFailure && failure.code == rateLimitedCode) {
      final minutes = failure.details['minutes'];
      final m = minutes is num ? minutes.toInt() : int.tryParse('$minutes');
      return RecoveryIssue(RecoveryIssueKind.rateLimited, seconds: m == null ? null : m * 60, minutes: m);
    }
    return const RecoveryIssue(RecoveryIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, seconds, attemptsLeft, minutes];
}
