import 'package:equatable/equatable.dart';

/// A hospital a medical-treatment request can be placed with, and how many places it has left
/// this week (Figma BOOK-10). Pure Dart.
class Hospital extends Equatable {
  const Hospital({required this.id, required this.name, required this.capacity, required this.remaining});

  final String id;
  final String name;

  /// Places this week.
  final int capacity;

  /// Places still free this week.
  final int remaining;

  bool get isFull => remaining <= 0;

  /// Fewer than a fifth left: shown amber.
  bool get isLow => !isFull && capacity > 0 && remaining / capacity <= 0.2;

  /// How much of the capacity is taken, 0..1 (the bar in the design).
  double get usedFraction => capacity <= 0 ? 1 : ((capacity - remaining) / capacity).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [id, name, capacity, remaining];
}

/// The hospital a booking was placed with (what the request carries and the review shows).
class HospitalChoice extends Equatable {
  const HospitalChoice({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
