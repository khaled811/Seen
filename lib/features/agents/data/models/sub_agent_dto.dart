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
  });

  factory SubAgentDto.fromJson(Map<String, dynamic> json) => SubAgentDto(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        balanceAmount: json['balanceAmount'] as String,
        isActive: json['isActive'] as bool,
        marginPercent: (json['marginPercent'] as num?)?.toDouble(),
      );

  final String id;
  final String name;
  final String code;

  /// Decimal string (e.g. `"1234.50"`) — never parsed as `double`.
  final String balanceAmount;
  final bool isActive;
  final double? marginPercent;

  SubAgent toEntity() => SubAgent(
        id: id,
        name: name,
        code: code,
        balanceCents: MoneyParser.centsFromDecimalString(balanceAmount),
        isActive: isActive,
        marginPercent: marginPercent,
      );
}
