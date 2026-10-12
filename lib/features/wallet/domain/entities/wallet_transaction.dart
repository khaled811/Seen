import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// One entry in the wallet's double-entry ledger.
class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.side,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.createdAt,
    this.referenceId,
    this.notes,
  });

  final String id;
  final TransactionType type;
  final LedgerSide side;
  final TransactionStatus status;
  final int amountCents;
  final WalletCurrency currency;
  final DateTime createdAt;
  final String? referenceId;
  final String? notes;

  @override
  List<Object?> get props => [
        id,
        type,
        side,
        status,
        amountCents,
        currency,
        createdAt,
        referenceId,
        notes,
      ];
}
