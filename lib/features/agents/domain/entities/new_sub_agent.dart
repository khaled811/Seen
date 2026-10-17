import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// What the master agent fills in to add a sub-agent (Figma AGT-01). Pure Dart.
class NewSubAgent extends Equatable {
  const NewSubAgent({
    required this.agencyName,
    required this.managerName,
    required this.phone,
    this.email,
    this.marginPercent,
    this.creditLimitCents,
    this.sendInvite = true,
  });

  final String agencyName;
  final String managerName;

  /// E.164.
  final String phone;
  final String? email;
  final double? marginPercent;
  final int? creditLimitCents;

  /// Send the login invitation (a link to create a password) to the phone / email.
  final bool sendInvite;

  @override
  List<Object?> get props => [
        agencyName,
        managerName,
        phone,
        email,
        marginPercent,
        creditLimitCents,
        sendInvite
      ];
}

enum SubAgentIssueKind {
  phoneTaken,
  emailTaken,

  /// New credit limit under what the sub-agent already uses (AGT-02).
  limitBelowUsage,

  /// New credit limit over what the master agent may grant (AGT-02).
  limitAboveAllowed,
  offline,
  generic,
}

/// A [Failure] in the vocabulary of the add-agent / credit-limit screens.
class SubAgentIssue extends Equatable {
  const SubAgentIssue(this.kind, {this.amountCents});

  final SubAgentIssueKind kind;

  /// `limitBelowUsage`: the current usage; `limitAboveAllowed`: the maximum.
  final int? amountCents;

  /// Backend error codes (GraphQL `extensions.code`) this mapping expects.
  /// TODO(backend-contract): confirm the names; see docs/BACKEND_MIGRATION_GAPS.md.
  static const phoneTakenCode = 'SUBAGENT_PHONE_TAKEN';
  static const emailTakenCode = 'SUBAGENT_EMAIL_TAKEN';
  static const limitBelowUsageCode = 'CREDIT_LIMIT_BELOW_USAGE';
  static const limitAboveAllowedCode = 'CREDIT_LIMIT_ABOVE_ALLOWED';

  factory SubAgentIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const SubAgentIssue(SubAgentIssueKind.offline);
    }
    if (failure is ServerFailure) {
      int? cents(String key) {
        final v = failure.details[key];
        return v is num ? v.toInt() : int.tryParse('$v');
      }

      return switch (failure.code) {
        phoneTakenCode => const SubAgentIssue(SubAgentIssueKind.phoneTaken),
        emailTakenCode => const SubAgentIssue(SubAgentIssueKind.emailTaken),
        limitBelowUsageCode => SubAgentIssue(SubAgentIssueKind.limitBelowUsage,
            amountCents: cents('usedCents')),
        limitAboveAllowedCode => SubAgentIssue(
            SubAgentIssueKind.limitAboveAllowed,
            amountCents: cents('maxCents')),
        _ => const SubAgentIssue(SubAgentIssueKind.generic),
      };
    }
    return const SubAgentIssue(SubAgentIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, amountCents];
}
