import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';

/// Maps backend enums to localized display text. Centralized so the screen
/// and the top-up sheet stay in sync.
abstract final class WalletLabels {
  static String transactionType(AppLocalizations l10n, TransactionType type) =>
      switch (type) {
        TransactionType.topup => l10n.transactionTypeTopup,
        TransactionType.hold => l10n.transactionTypeHold,
        TransactionType.finalDeduction => l10n.transactionTypeFinalDeduction,
        TransactionType.release => l10n.transactionTypeRelease,
        TransactionType.refund => l10n.transactionTypeRefund,
        TransactionType.settlement => l10n.transactionTypeSettlement,
        TransactionType.unknown => l10n.error,
      };

  static String transactionStatus(AppLocalizations l10n, TransactionStatus status) =>
      switch (status) {
        TransactionStatus.pending => l10n.transactionStatusPending,
        TransactionStatus.approved => l10n.transactionStatusApproved,
        TransactionStatus.rejected => l10n.transactionStatusRejected,
        TransactionStatus.unknown => l10n.error,
      };

  static String topUpMethod(AppLocalizations l10n, TopUpMethod method) => switch (method) {
        TopUpMethod.bankTransfer => l10n.topUpMethodBankTransfer,
        TopUpMethod.cash => l10n.topUpMethodCash,
        TopUpMethod.exchangeHouse => l10n.topUpMethodExchangeHouse,
        TopUpMethod.unknown => l10n.error,
      };
}
