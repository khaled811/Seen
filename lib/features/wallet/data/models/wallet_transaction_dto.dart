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
      );
}
