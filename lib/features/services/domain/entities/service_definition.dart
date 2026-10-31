import 'package:equatable/equatable.dart';

import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';

/// Which government/carrier approval a service maps to.
///
/// NOTE: these are the app's own field names. The real wire shape is read by the mapping beside this class and every document is checked against `docs/api/` in tests.
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

/// A document a service asks for per traveler (`ServiceDocumentRequirement`).
class ServiceDocumentRequirement extends Equatable {
  const ServiceDocumentRequirement({
    required this.id,
    required this.key,
    required this.label,
    required this.required,
  });

  final String id;
  final String key;
  final String label;
  final bool required;

  @override
  List<Object?> get props => [id, key, label, required];
}

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
    this.code,
    this.slaHours,
    this.requiresApproval = false,
    this.fields = const [],
    this.documents = const [],
  });

  final String id;
  final ServiceCategory category;
  final String name;
  final String description;
  final int perPersonPriceCents;
  final ServiceAvailability availability;

  /// The server's service code (`ServiceType.code`).
  final String? code;
  final int? slaHours;
  final bool requiresApproval;

  /// What to ask per traveler (server-driven, ordered by step then display
  /// order) and which documents to collect. Empty for a service that has none.
  final List<DynamicFormField> fields;
  final List<ServiceDocumentRequirement> documents;

  bool get isBookable => availability == ServiceAvailability.available;

  @override
  List<Object?> get props =>
      [id, category, name, description, perPersonPriceCents, availability, code, slaHours, requiresApproval, fields, documents];
}
