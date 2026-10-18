import 'package:equatable/equatable.dart';

import 'traveler_info.dart';

/// A submission: one service, one or more travelers.
class ServiceBookingRequest extends Equatable {
  const ServiceBookingRequest({required this.serviceId, required this.travelers, this.hospitalId});

  final String serviceId;
  final List<TravelerInfo> travelers;

  /// The hospital chosen for a medical service (Figma BOOK-10); null for the others.
  final String? hospitalId;

  int get travelerCount => travelers.length;

  @override
  List<Object?> get props => [serviceId, travelers, hospitalId];
}
