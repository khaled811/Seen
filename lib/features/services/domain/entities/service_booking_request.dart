import 'package:equatable/equatable.dart';

import 'traveler_info.dart';

/// A submission: one service, one or more travelers.
class ServiceBookingRequest extends Equatable {
  const ServiceBookingRequest({required this.serviceId, required this.travelers});

  final String serviceId;
  final List<TravelerInfo> travelers;

  int get travelerCount => travelers.length;

  @override
  List<Object?> get props => [serviceId, travelers];
}
