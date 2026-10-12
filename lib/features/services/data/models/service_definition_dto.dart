import '../../../../core/utils/money.dart';
import '../../domain/entities/service_definition.dart';

/// Wire shape of one service catalog entry.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema — update here and in
/// `services_remote_data_source.dart` once confirmed.
class ServiceDefinitionDto {
  const ServiceDefinitionDto({
    required this.id,
    required this.name,
    required this.perPersonPriceAmount,
    this.category,
    this.description,
    this.availability,
  });

  factory ServiceDefinitionDto.fromJson(Map<String, dynamic> json) =>
      ServiceDefinitionDto(
        id: json['id'] as String,
        category: json['category'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        perPersonPriceAmount: json['perPersonPriceAmount'] as String,
        availability: json['availability'] as String?,
      );

  final String id;
  final String? category;
  final String name;
  final String? description;

  /// Decimal string (e.g. `"150.00"`) — never parsed as `double`.
  final String perPersonPriceAmount;

  /// `"available"` or `"coming_soon"`; anything else defaults to not-yet-bookable.
  final String? availability;

  ServiceDefinition toEntity() => ServiceDefinition(
        id: id,
        category: ServiceCategory.fromValue(category),
        name: name,
        description: description ?? '',
        perPersonPriceCents: MoneyParser.centsFromDecimalString(perPersonPriceAmount),
        availability: availability == 'available'
            ? ServiceAvailability.available
            : ServiceAvailability.comingSoon,
      );
}
