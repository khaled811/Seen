import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/service_booking_result.dart';

/// Wire shape of a submitted booking's acknowledgement.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema.
class ServiceBookingResultDto {
  const ServiceBookingResultDto({
    required this.requestId,
    required this.totalPriceAmount,
    required this.createdAt,
    this.status,
  });

  factory ServiceBookingResultDto.fromJson(Map<String, dynamic> json) =>
      ServiceBookingResultDto(
        requestId: json['requestId'] as String,
        status: json['status'] as String?,
        totalPriceAmount: json['totalPriceAmount'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String requestId;
  final String? status;
  final String totalPriceAmount;
  final DateTime createdAt;

  ServiceBookingResult toEntity() => ServiceBookingResult(
        requestId: requestId,
        status: RequestStatus.fromValue(status),
        totalPriceCents: MoneyParser.centsFromDecimalString(totalPriceAmount),
        createdAt: createdAt,
      );
}
