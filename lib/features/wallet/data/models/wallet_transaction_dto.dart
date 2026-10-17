import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/wallet_transaction.dart';

/// Wire shape of one ledger entry.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema — update here and in
/// `wallet_remote_data_source.dart` once confirmed.
class WalletTransactionDto {
  const WalletTransactionDto({
    required this.id,
    required this.type,
    required this.side,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.currency,
    this.referenceId,
    this.notes,
    this.balanceAfter,
    this.request,
    this.topUp,
  });

  factory WalletTransactionDto.fromJson(Map<String, dynamic> json) =>
      WalletTransactionDto(
        id: json['id'] as String,
        type: json['type'] as String?,
        side: json['side'] as String?,
        status: json['status'] as String?,
        amount: json['amount'] as String,
        currency: json['currency'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        referenceId: json['referenceId'] as String?,
        notes: json['notes'] as String?,
        balanceAfter: json['balanceAfter'] as String?,
        request: json['request'] == null
            ? null
            : LinkedRequestDto.fromJson(json['request'] as Map<String, dynamic>),
        topUp: json['topUp'] == null ? null : TopUpInfoDto.fromJson(json['topUp'] as Map<String, dynamic>),
      );

  final String id;
  final String? type;
  final String? side;
  final String? status;

  /// Decimal string (e.g. `"1234.50"`) — never parsed as `double`.
  final String amount;
  final String? currency;
  final DateTime createdAt;
  final String? referenceId;
  final String? notes;

  /// TODO(backend-contract): placeholders (docs/BACKEND_MIGRATION_GAPS.md, section 23).
  final String? balanceAfter;
  final LinkedRequestDto? request;
  final TopUpInfoDto? topUp;

  WalletTransaction toEntity() => WalletTransaction(
        id: id,
        type: TransactionType.fromValue(type),
        side: LedgerSide.fromValue(side),
        status: TransactionStatus.fromValue(status),
        amountCents: MoneyParser.centsFromDecimalString(amount),
        currency: WalletCurrency.fromValue(currency),
        createdAt: createdAt,
        referenceId: referenceId,
        notes: notes,
        balanceAfterCents: balanceAfter == null ? null : MoneyParser.centsFromDecimalString(balanceAfter!),
        request: request?.toEntity(),
        topUp: topUp?.toEntity(),
      );
}

class LinkedRequestDto {
  const LinkedRequestDto({required this.id, required this.referenceId, this.serviceName});

  factory LinkedRequestDto.fromJson(Map<String, dynamic> json) => LinkedRequestDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        serviceName: json['serviceName'] as String?,
      );

  final String id;
  final String referenceId;
  final String? serviceName;

  LinkedRequest toEntity() => LinkedRequest(id: id, referenceId: referenceId, serviceName: serviceName);
}

class TopUpInfoDto {
  const TopUpInfoDto({
    this.method,
    this.code,
    this.bankName,
    this.transferReference,
    this.receiptName,
    this.receiptUrl,
    this.rejectionReason,
  });

  factory TopUpInfoDto.fromJson(Map<String, dynamic> json) => TopUpInfoDto(
        method: json['method'] as String?,
        code: json['code'] as String?,
        bankName: json['bankName'] as String?,
        transferReference: json['transferReference'] as String?,
        receiptName: json['receiptName'] as String?,
        receiptUrl: json['receiptUrl'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
      );

  final String? method;
  final String? code;
  final String? bankName;
  final String? transferReference;
  final String? receiptName;
  final String? receiptUrl;
  final String? rejectionReason;

  TopUpInfo toEntity() => TopUpInfo(
        method: TopUpMethod.fromValue(method),
        code: code,
        bankName: bankName,
        transferReference: transferReference,
        receiptName: receiptName,
        receiptUrl: receiptUrl,
        rejectionReason: rejectionReason,
      );
}
