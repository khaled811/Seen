import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/wallet_balance.dart';

/// Wire shape of the wallet balance query.
///
/// NOTE: these are the app's own field names. The real wire shape is read by the mapping beside this class and every document is checked against `docs/api/` in tests.
class WalletBalanceDto {
  const WalletBalanceDto({
    required this.availableAmount,
    required this.holdAmount,
    required this.creditLimitAmount,
    required this.currency,
    this.creditUsedAmount,
    this.spendableAmount,
    this.totalAmount,
  });

  factory WalletBalanceDto.fromJson(Map<String, dynamic> json) => WalletBalanceDto(
        availableAmount: json['availableAmount'] as String,
        holdAmount: json['holdAmount'] as String,
        creditLimitAmount: json['creditLimitAmount'] as String,
        currency: json['currency'] as String?,
        creditUsedAmount: json['creditUsedAmount'] as String?,
        spendableAmount: json['spendableAmount'] as String?,
        totalAmount: json['totalAmount'] as String?,
      );

  /// Decimal strings (e.g. `"1234.50"`) — never parsed as `double`.
  final String availableAmount;
  final String holdAmount;
  final String creditLimitAmount;
  final String? currency;

  /// NOTE: these are the app's own field names. The real wire shape is read by the mapping beside this class and every document is checked against `docs/api/` in tests.
  final String? creditUsedAmount;
  final String? spendableAmount;
  final String? totalAmount;

  WalletBalance toEntity() => WalletBalance(
        availableCents: MoneyParser.centsFromDecimalString(availableAmount),
        holdCents: MoneyParser.centsFromDecimalString(holdAmount),
        creditLimitCents: MoneyParser.centsFromDecimalString(creditLimitAmount),
        currency: WalletCurrency.fromValue(currency),
        creditUsedCents: creditUsedAmount == null ? null : MoneyParser.centsFromDecimalString(creditUsedAmount!),
        spendableCents: spendableAmount == null ? null : MoneyParser.centsFromDecimalString(spendableAmount!),
        reportedTotalCents: totalAmount == null ? null : MoneyParser.centsFromDecimalString(totalAmount!),
      );
}
