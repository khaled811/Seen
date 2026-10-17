import '../../../../core/utils/money.dart';
import '../../domain/entities/sub_agent.dart';

/// Wire shape of one sub-agent.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema — update here and in
/// `agents_remote_data_source.dart` once confirmed.
class SubAgentDto {
  const SubAgentDto({
    required this.id,
    required this.name,
    required this.code,
    required this.balanceAmount,
    required this.isActive,
    this.marginPercent,
    this.creditLimitAmount,
    this.creditUsedAmount,
    this.invitePending = false,
  });

  factory SubAgentDto.fromJson(Map<String, dynamic> json) => SubAgentDto(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        balanceAmount: json['balanceAmount'] as String,
        isActive: json['isActive'] as bool,
        marginPercent: (json['marginPercent'] as num?)?.toDouble(),
        creditLimitAmount: json['creditLimitAmount'] as String?,
        creditUsedAmount: json['creditUsedAmount'] as String?,
        invitePending: json['invitePending'] as bool? ?? false,
      );

  final String id;
  final String name;
  final String code;

  /// Decimal string (e.g. `"1234.50"`) — never parsed as `double`.
  final String balanceAmount;
  final bool isActive;
  final double? marginPercent;

  /// Decimal strings, like [balanceAmount].
  final String? creditLimitAmount;
  final String? creditUsedAmount;
  final bool invitePending;

  SubAgentDto copyWith({
    String? balanceAmount,
    bool? isActive,
    String? creditLimitAmount,
    bool? invitePending,
  }) =>
      SubAgentDto(
        id: id,
        name: name,
        code: code,
        balanceAmount: balanceAmount ?? this.balanceAmount,
        isActive: isActive ?? this.isActive,
        marginPercent: marginPercent,
        creditLimitAmount: creditLimitAmount ?? this.creditLimitAmount,
        creditUsedAmount: creditUsedAmount,
        invitePending: invitePending ?? this.invitePending,
      );

  SubAgent toEntity() => SubAgent(
        id: id,
        name: name,
        code: code,
        balanceCents: MoneyParser.centsFromDecimalString(balanceAmount),
        isActive: isActive,
        marginPercent: marginPercent,
        creditLimitCents: creditLimitAmount == null
            ? null
            : MoneyParser.centsFromDecimalString(creditLimitAmount!),
        creditUsedCents: creditUsedAmount == null
            ? null
            : MoneyParser.centsFromDecimalString(creditUsedAmount!),
        invitePending: invitePending,
      );
}
