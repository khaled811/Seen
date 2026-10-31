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
    this.ownerName,
    this.requestCount,
    this.monthRequestCount,
    this.canFund = true,
    this.canSuspend = true,
    this.canActivate = true,
    this.balanceKnown = true,
  });

  final String id;
  final String name;

  /// What the list shows under the name. The API has no agency code (DECISIONS
  /// Q13), so this carries the city.
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

  /// Pending (`status` = `pending`): created but not active yet.
  final bool invitePending;

  /// The agency owner's name, when the server says it.
  final String? ownerName;
  final int? requestCount;
  final int? monthRequestCount;

  /// What the server lets this person do with this agency (`canFund`,
  /// `canSuspend`, `canActivate`): the controls follow these, not the app's own idea.
  final bool canFund;
  final bool canSuspend;
  final bool canActivate;

  /// False when the server shows no balance (the agency has no wallet in the default
  /// currency): the screens show a dash, never 0.
  final bool balanceKnown;

  SubAgent copyWith({int? balanceCents, bool? isActive, bool? invitePending}) => SubAgent(
        id: id,
        name: name,
        code: code,
        balanceCents: balanceCents ?? this.balanceCents,
        isActive: isActive ?? this.isActive,
        marginPercent: marginPercent,
        creditLimitCents: creditLimitCents,
        creditUsedCents: creditUsedCents,
        invitePending: invitePending ?? this.invitePending,
        ownerName: ownerName,
        requestCount: requestCount,
        monthRequestCount: monthRequestCount,
        canFund: canFund,
        canSuspend: canSuspend,
        canActivate: canActivate,
        balanceKnown: balanceKnown,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        balanceCents,
        isActive,
        marginPercent,
        creditLimitCents,
        creditUsedCents,
        invitePending,
        ownerName,
        requestCount,
        monthRequestCount,
        canFund,
        canSuspend,
        canActivate,
        balanceKnown,
      ];
}
