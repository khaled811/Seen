import '../../../../core/constants/enums.dart';
import '../../domain/entities/service_booking_result.dart';

/// Parses the `Request` that `submitRequest` returns.
abstract final class SubmittedRequestDto {
  static ServiceBookingResult parse(Map<String, dynamic> json) => ServiceBookingResult(
        requestId: json['id'].toString(),
        status: RequestStatus.fromValue(json['status'] as String?),
        referenceCode: json['referenceCode'] as String?,
      );
}
