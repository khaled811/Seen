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
    this.creditUsedCents,
  });

  /// Free to spend right now.
  final int availableCents;

  /// Committed to submitted/under-review requests, not yet finalized.
  final int holdCents;

  final int creditLimitCents;
  final WalletCurrency currency;

  /// How much of [creditLimitCents] is in use (Figma WAL-10); null when the
  /// server does not say.
  final int? creditUsedCents;

  /// Derived, not a separately-trusted backend field: total is definitionally
  /// available + hold, and treating it as anything else risks the two
  /// silently disagreeing.
  int get totalCents => availableCents + holdCents;

  /// Nothing available and nothing held (Figma WAL-08 "zero").
  bool get isZero => availableCents == 0 && holdCents == 0;

  /// What is owed beyond the credit limit (0 when within it): the available
  /// balance is negative by more than [creditLimitCents] (Figma WAL-08).
  /// Derived on the device from these three fields; the backend may prefer to
  /// say it outright (docs/BACKEND_MIGRATION_GAPS.md, section 25).
  int get overLimitCents {
    final excess = -availableCents - creditLimitCents;
    return excess > 0 ? excess : 0;
  }

  bool get isOverLimit => overLimitCents > 0;

  /// Credit that can still be used (limit minus used), or null while the server
  /// does not say how much is in use.
  int? get creditRemainingCents {
    final used = creditUsedCents;
    if (used == null) return null;
    final left = creditLimitCents - used;
    return left > 0 ? left : 0;
  }

  /// 0..1 share of the credit limit in use, or null without both numbers.
  double? get creditUsedFraction {
    final used = creditUsedCents;
    if (used == null || creditLimitCents <= 0) return null;
    return (used / creditLimitCents).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [availableCents, holdCents, creditLimitCents, currency, creditUsedCents];
}
