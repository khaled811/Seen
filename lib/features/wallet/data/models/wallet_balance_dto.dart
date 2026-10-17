import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/wallet_balance.dart';

/// Wire shape of the wallet balance query.
///
/// TODO(backend-contract): field names (`availableAmount`, `holdAmount`,
/// `creditLimitAmount`, `currency`) are placeholders pending the real Seen
/// Booking GraphQL schema — update here and in `wallet_remote_data_source.dart`
/// once confirmed.
class WalletBalanceDto {
  const WalletBalanceDto({
    required this.availableAmount,
    required this.holdAmount,
    required this.creditLimitAmount,
    required this.currency,
    this.creditUsedAmount,
  });

  factory WalletBalanceDto.fromJson(Map<String, dynamic> json) => WalletBalanceDto(
        availableAmount: json['availableAmount'] as String,
        holdAmount: json['holdAmount'] as String,
        creditLimitAmount: json['creditLimitAmount'] as String,
        currency: json['currency'] as String?,
        creditUsedAmount: json['creditUsedAmount'] as String?,
      );

  /// Decimal strings (e.g. `"1234.50"`) — never parsed as `double`.
  final String availableAmount;
  final String holdAmount;
  final String creditLimitAmount;
  final String? currency;

  /// TODO(backend-contract): placeholder (docs/BACKEND_MIGRATION_GAPS.md, section 25).
  final String? creditUsedAmount;

  WalletBalance toEntity() => WalletBalance(
        availableCents: MoneyParser.centsFromDecimalString(availableAmount),
        holdCents: MoneyParser.centsFromDecimalString(holdAmount),
        creditLimitCents: MoneyParser.centsFromDecimalString(creditLimitAmount),
        currency: WalletCurrency.fromValue(currency),
        creditUsedCents: creditUsedAmount == null ? null : MoneyParser.centsFromDecimalString(creditUsedAmount!),
      );
}
