import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

sealed class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on screen entry and on pull-to-refresh.
final class WalletLoadRequested extends WalletEvent {
  const WalletLoadRequested();
}

/// Client-side filter over the already-loaded transaction page — a `null`
/// type clears the filter. Not a server round trip; see `WalletRepository`
/// for the (currently UI-unwired) server-side filter/date-range params.
final class WalletTransactionTypeFilterChanged extends WalletEvent {
  const WalletTransactionTypeFilterChanged(this.type);

  final TransactionType? type;

  @override
  List<Object?> get props => [type];
}

final class WalletTopUpSubmitted extends WalletEvent {
  const WalletTopUpSubmitted({
    required this.amountCents,
    required this.method,
    required this.referenceNumber,
    this.paymentAccountId,
    this.receiptFileId,
  });

  final int amountCents;
  final TopUpMethod method;
  final String referenceNumber;

  /// The Seen account paid into (from the top-up options), when one applies.
  final String? paymentAccountId;

  /// A receipt already uploaded with `kind=ticket_attachment`.
  final String? receiptFileId;

  @override
  List<Object?> get props => [amountCents, method, referenceNumber, paymentAccountId, receiptFileId];
}

/// Dispatched by the UI once it has shown a completed top-up's
/// success/failure feedback, so the status doesn't linger and re-trigger it.
final class WalletTopUpStatusCleared extends WalletEvent {
  const WalletTopUpStatusCleared();
}
