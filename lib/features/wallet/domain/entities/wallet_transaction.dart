import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The request a hold / deduction / refund belongs to (Figma WAL-01).
class LinkedRequest extends Equatable {
  const LinkedRequest({required this.id, required this.referenceId, this.serviceName});

  final String id;
  final String referenceId;
  final String? serviceName;

  @override
  List<Object?> get props => [id, referenceId, serviceName];
}

/// What a top-up request carries beyond the ledger row (Figma WAL-02 / 03).
class TopUpInfo extends Equatable {
  const TopUpInfo({
    required this.method,
    this.code,
    this.bankName,
    this.transferReference,
    this.receiptName,
    this.receiptUrl,
    this.rejectionReason,
  });

  final TopUpMethod method;

  /// The request's own number, e.g. "TU-2281".
  final String? code;
  final String? bankName;
  final String? transferReference;
  final String? receiptName;
  final String? receiptUrl;

  /// Why finance rejected it (only when the transaction is rejected).
  final String? rejectionReason;

  @override
  List<Object?> get props => [method, code, bankName, transferReference, receiptName, receiptUrl, rejectionReason];
}

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
    this.balanceAfterCents,
    this.request,
    this.topUp,
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

  /// The available balance right after this entry posted.
  final int? balanceAfterCents;
  final LinkedRequest? request;

  /// Set for top-ups.
  final TopUpInfo? topUp;

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
        balanceAfterCents,
        request,
        topUp,
      ];
}
