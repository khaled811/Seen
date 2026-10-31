import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import 'wallet_balance_dto.dart';
import 'wallet_transaction_dto.dart';

/// Maps the wire shapes of `portalWallet` (`docs/api/mobile-api-reference.md`:
/// `PortalWalletSummary`, `PortalStatementRow`, `PortalPendingTopUp`) to the
/// wallet DTOs the repository already understands. Amounts stay `Decimal`
/// strings; they are parsed to integer cents later, never through a `double`.
abstract final class PortalWalletMapping {
  /// `summary { balance held total creditLimit spendable creditUsed currency }`.
  ///
  /// The server's definitions are used as they are: `balance` is what the
  /// wallet shows as available, `held` what is held for requests under
  /// approval, `total` and `spendable` are the server's own figures.
  static WalletBalanceDto balance(Map<String, dynamic> summary) => WalletBalanceDto(
        availableAmount: summary['balance'] as String,
        holdAmount: summary['held'] as String,
        creditLimitAmount: summary['creditLimit'] as String,
        creditUsedAmount: summary['creditUsed'] as String?,
        spendableAmount: summary['spendable'] as String?,
        totalAmount: summary['total'] as String?,
        currency: summary['currency'] as String?,
      );

  /// A posted movement: `PortalStatementRow`. Statement rows are posted, so
  /// they are `approved`; a request-related row carries the request.
  static WalletTransactionDto statementRow(Map<String, dynamic> row, AppLanguage language) {
    final requestId = row['requestId'] as String?;
    final type = row['type'] as String?;
    final method = row['method'] as String?;
    return WalletTransactionDto(
      id: row['id'] as String,
      type: type,
      side: row['direction'] as String?,
      status: TransactionStatus.approved.value,
      amount: row['amount'] as String,
      currency: row['currency'] as String?,
      createdAt: DateTime.parse(row['createdAt'] as String),
      balanceAfter: row['balanceAfter'] as String?,
      request: requestId == null
          ? null
          : LinkedRequestDto(
              id: requestId,
              referenceId: row['referenceCode'] as String? ?? '',
              serviceName: language.pick(ar: row['serviceNameAr'] as String?, en: row['serviceNameEn'] as String?),
            ),
      topUp: type == TransactionType.topup.value && method != null ? TopUpInfoDto(method: method) : null,
    );
  }

  /// A top-up still waiting for Seen: `PortalPendingTopUp`.
  static WalletTransactionDto pendingTopUp(Map<String, dynamic> row) => WalletTransactionDto(
        id: row['id'] as String,
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: TransactionStatus.pending.value,
        amount: row['amount'] as String,
        currency: row['currency'] as String?,
        createdAt: DateTime.parse(row['createdAt'] as String),
        referenceId: row['number'] as String?,
        topUp: TopUpInfoDto(
          method: row['method'] as String?,
          code: row['number'] as String?,
          bankName: row['paymentAccountTitle'] as String?,
          transferReference: row['referenceNumber'] as String?,
        ),
      );

  /// `SubmittedTopUp` (the answer to `submitTopUp`): always pending.
  static WalletTransactionDto submittedTopUp(Map<String, dynamic> row) => WalletTransactionDto(
        id: row['id'] as String,
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: (row['status'] as String?) ?? TransactionStatus.pending.value,
        amount: row['amount'] as String,
        currency: row['currency'] as String?,
        createdAt: DateTime.parse(row['createdAt'] as String),
        referenceId: row['number'] as String?,
        topUp: TopUpInfoDto(
          method: row['method'] as String?,
          code: row['number'] as String?,
          bankName: (row['paymentAccount'] as Map<String, dynamic>?)?['title'] as String?,
          transferReference: row['referenceNumber'] as String?,
        ),
      );
}
