import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The backend's acknowledgement of a submitted booking.
class ServiceBookingResult extends Equatable {
  const ServiceBookingResult({
    required this.requestId,
    required this.status,
    required this.totalPriceCents,
    required this.createdAt,
  });

  final String requestId;
  final RequestStatus status;
  final int totalPriceCents;
  final DateTime createdAt;

  @override
  List<Object?> get props => [requestId, status, totalPriceCents, createdAt];
}
