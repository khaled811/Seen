import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The server's answer to `submitRequest`.
class ServiceBookingResult extends Equatable {
  const ServiceBookingResult({
    required this.requestId,
    required this.status,
    this.referenceCode,
  });

  final String requestId;
  final RequestStatus status;

  /// The confirmation shown to the person (like `SB-20481`). It can lag the
  /// submit by a moment: null/empty until a re-read has it.
  final String? referenceCode;

  bool get hasReference => referenceCode != null && referenceCode!.isNotEmpty;

  ServiceBookingResult withReference(String reference) =>
      ServiceBookingResult(requestId: requestId, status: status, referenceCode: reference);

  @override
  List<Object?> get props => [requestId, status, referenceCode];
}
