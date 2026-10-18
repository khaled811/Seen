import 'package:equatable/equatable.dart';

/// Which government/carrier approval a service maps to.
///
/// TODO(backend-contract): not part of the confirmed Task 01 enum catalog —
/// these values are placeholders pending the real Seen Booking service
/// taxonomy. `unknown` covers any category not yet mapped.
enum ServiceCategory {
  egyptNationalSecurity('egypt_national_security'),
  egyptMilitaryIntelligence('egypt_military_intelligence'),

  /// Subtask 7.2 — scaffolded, not yet bookable.
  egyptAirlineCircular('egypt_airline_circular'),

  /// Subtask 7.3 — scaffolded, not yet bookable.
  jordanApprovals('jordan_approvals'),

  /// Treatment in Jordan (Figma BOOK-10): a hospital is chosen first, then the medical visa request.
  medicalJordan('medical_jordan'),

  unknown('');

  const ServiceCategory(this.value);
  final String value;

  static ServiceCategory fromValue(String? value) {
    for (final category in values) {
      if (category.value == value) return category;
    }
    return ServiceCategory.unknown;
  }
}

enum ServiceAvailability { available, comingSoon }

/// A bookable (or not-yet-bookable) service offering.
///
/// [name]/[description] are backend-provided content, not UI chrome — like
/// `WalletTransaction.notes`, they're data, not something resolved through
/// ARB. The per-traveler input fields a service needs are resolved
/// separately in the presentation layer (see `ServiceTravelerFields`),
/// since building them requires localized labels this entity can't hold
/// without pulling Flutter/l10n into the domain layer.
class ServiceDefinition extends Equatable {
  const ServiceDefinition({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.perPersonPriceCents,
    required this.availability,
  });

  final String id;
  final ServiceCategory category;
  final String name;
  final String description;
  final int perPersonPriceCents;
  final ServiceAvailability availability;

  bool get isBookable => availability == ServiceAvailability.available;

  @override
  List<Object?> get props =>
      [id, category, name, description, perPersonPriceCents, availability];
}
