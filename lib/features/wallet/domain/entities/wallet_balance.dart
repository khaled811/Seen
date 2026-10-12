import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The agency's wallet balance. USD only, per the current business rules —
/// [currency] is carried through anyway so a future multi-currency change
/// doesn't require touching every call site.
///
/// Amounts are integer cents; see `core/utils/money.dart` for why.
class WalletBalance extends Equatable {
  const WalletBalance({
    required this.availableCents,
    required this.holdCents,
    required this.creditLimitCents,
    required this.currency,
  });

  /// Free to spend right now.
  final int availableCents;

  /// Committed to submitted/under-review requests, not yet finalized.
  final int holdCents;

  final int creditLimitCents;
  final WalletCurrency currency;

  /// Derived, not a separately-trusted backend field: total is definitionally
  /// available + hold, and treating it as anything else risks the two
  /// silently disagreeing.
  int get totalCents => availableCents + holdCents;

  @override
  List<Object?> get props => [availableCents, holdCents, creditLimitCents, currency];
}
