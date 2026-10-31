import '../../../../core/error/password_rule.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// What the master agent fills in to add a sub-agency (Figma AGT-01): the
/// contract's `SubAgentInput`: the agency name and its owner (name, e-mail, the
/// first password). Pure Dart.
class NewSubAgent extends Equatable {
  const NewSubAgent({
    required this.agencyName,
    required this.managerName,
    required this.email,
    required this.password,
  });

  final String agencyName;
  final String managerName;
  final String email;

  /// The owner's first password, set by the master agent. It travels once with the
  /// request and is not part of equality.
  final String password;

  @override
  List<Object?> get props => [agencyName, managerName, email];
}

enum SubAgentIssueKind {
  emailTaken,
  weakPassword,

  /// A sub-agency cannot create its own, or the person may not (permission).
  notAllowed,

  /// The amount is more than the master agent's own balance / the sub-agency's.
  amountExceedsBalance,
  offline,
  generic,
}

/// A [Failure] in the vocabulary of the add-agent screen.
class SubAgentIssue extends Equatable {
  const SubAgentIssue(this.kind, {this.passwordRule});

  final SubAgentIssueKind kind;

  /// The password rule the server named (`weakPassword` only).
  final String? passwordRule;

  /// Error codes of the contract.
  static const emailTakenCode = 'owner_email_taken';
  static const weakPasswordCode = 'password_weak';
  static const subAgentDepthCode = 'sub_agent_depth';
  static const fundsExceedBalanceCode = 'funds_exceed_balance';
  static const reclaimExceedsBalanceCode = 'reclaim_exceeds_balance';

  factory SubAgentIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const SubAgentIssue(SubAgentIssueKind.offline);
    }
    if (failure is ForbiddenFailure) {
      return const SubAgentIssue(SubAgentIssueKind.notAllowed);
    }
    if (failure is ServerFailure) {
      return switch (failure.code) {
        emailTakenCode => const SubAgentIssue(SubAgentIssueKind.emailTaken),
        weakPasswordCode => SubAgentIssue(SubAgentIssueKind.weakPassword, passwordRule: passwordRuleOf(failure)),
        subAgentDepthCode => const SubAgentIssue(SubAgentIssueKind.notAllowed),
        fundsExceedBalanceCode ||
        reclaimExceedsBalanceCode =>
          const SubAgentIssue(SubAgentIssueKind.amountExceedsBalance),
        _ => const SubAgentIssue(SubAgentIssueKind.generic),
      };
    }
    return const SubAgentIssue(SubAgentIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, passwordRule];
}
