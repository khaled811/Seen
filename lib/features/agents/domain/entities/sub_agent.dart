import 'package:equatable/equatable.dart';

/// One sub-agent/branch under the logged-in master agent.
class SubAgent extends Equatable {
  const SubAgent({
    required this.id,
    required this.name,
    required this.code,
    required this.balanceCents,
    required this.isActive,
    this.marginPercent,
    this.creditLimitCents,
    this.creditUsedCents,
    this.invitePending = false,
  });

  final String id;
  final String name;
  final String code;
  final int balanceCents;
  final bool isActive;

  /// Price markup/margin assigned to this sub-agent, e.g. `5.5` for 5.5%.
  /// `null` when none is assigned. A percentage rather than a currency
  /// amount — it's a display/config value, never summed into ledger
  /// arithmetic, so unlike money it doesn't need an integer-cents
  /// representation.
  final double? marginPercent;

  /// Credit the master agent granted, and how much of it is in use. `null`
  /// when the backend does not say.
  final int? creditLimitCents;
  final int? creditUsedCents;

  /// Invited but has not accepted yet ("activating").
  final bool invitePending;

  @override
  List<Object?> get props =>
      [id, name, code, balanceCents, isActive, marginPercent, creditLimitCents, creditUsedCents, invitePending];
}
