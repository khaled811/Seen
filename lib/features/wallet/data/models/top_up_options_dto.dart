import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/top_up_options.dart';

/// Wire shape of `portalTopUpOptions`.
class TopUpOptionsDto {
  const TopUpOptionsDto({
    required this.currency,
    required this.methods,
    required this.accounts,
    required this.canRequest,
    this.minimumAmount,
    this.pendingCount = 0,
  });

  factory TopUpOptionsDto.fromJson(Map<String, dynamic> json) => TopUpOptionsDto(
        currency: json['currency'] as String? ?? '',
        minimumAmount: json['minimumAmount'] as String?,
        canRequest: json['canRequest'] as bool? ?? false,
        pendingCount: json['pendingCount'] as int? ?? 0,
        methods: [
          for (final m in json['methods'] as List<dynamic>? ?? const [])
            (
              method: (m as Map<String, dynamic>)['method'] as String? ?? '',
              accountKinds: [for (final k in m['accountKinds'] as List<dynamic>? ?? const []) k as String],
            ),
        ],
        accounts: [
          for (final a in json['accounts'] as List<dynamic>? ?? const [])
            if ((a as Map<String, dynamic>)['isActive'] != false) PaymentAccountDto.fromJson(a),
        ],
      );

  final String currency;
  final String? minimumAmount;
  final bool canRequest;
  final int pendingCount;
  final List<({String method, List<String> accountKinds})> methods;
  final List<PaymentAccountDto> accounts;

  TopUpOptions toEntity() => TopUpOptions(
        currency: currency,
        minimumAmountCents: minimumAmount == null ? null : MoneyParser.centsFromDecimalString(minimumAmount!),
        canRequest: canRequest,
        pendingCount: pendingCount,
        // A method the app has no card for is dropped rather than shown raw.
        methods: [
          for (final m in methods)
            if (TopUpMethod.fromValue(m.method) != TopUpMethod.unknown)
              TopUpMethodOption(
                method: TopUpMethod.fromValue(m.method),
                accountKinds: [for (final k in m.accountKinds) PaymentAccountKind.fromValue(k)],
              ),
        ],
        accounts: [for (final a in accounts) a.toEntity()],
      );
}

class PaymentAccountDto {
  const PaymentAccountDto({
    required this.id,
    required this.kind,
    required this.title,
    required this.holder,
    required this.bankName,
    required this.accountNumber,
    required this.currency,
    required this.instructions,
  });

  factory PaymentAccountDto.fromJson(Map<String, dynamic> json) => PaymentAccountDto(
        id: json['id'] as String,
        kind: json['kind'] as String?,
        title: json['title'] as String? ?? '',
        holder: json['holder'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        currency: json['currency'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
      );

  final String id;
  final String? kind;
  final String title;
  final String holder;
  final String bankName;
  final String accountNumber;
  final String currency;
  final String instructions;

  PaymentAccount toEntity() => PaymentAccount(
        id: id,
        kind: PaymentAccountKind.fromValue(kind),
        title: title,
        holder: holder,
        bankName: bankName,
        accountNumber: accountNumber,
        currency: currency,
        instructions: instructions,
      );
}
