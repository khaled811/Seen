import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/service_definition.dart';
import 'service_field_mapper.dart';

/// Wire shape of one service catalog entry.
///
/// NOTE: these are the app's own field names. The real wire shape is read by the mapping beside this class and every document is checked against `docs/api/` in tests.
class ServiceDefinitionDto {
  const ServiceDefinitionDto({
    required this.id,
    required this.name,
    required this.perPersonPriceAmount,
    this.category,
    this.description,
    this.availability,
    this.code,
    this.slaHours,
    this.requiresApproval = false,
    this.fields = const [],
    this.documents = const [],
  });

  /// One `ServiceType` of `availableServices` (contract 10.2). A service with
  /// no `myPrice` (not priced for this agency) or that is inactive is listed
  /// but not bookable; the price stays a decimal string until it is cents.
  factory ServiceDefinitionDto.fromServerJson(Map<String, dynamic> json, AppLanguage language) {
    // The contract has no way to send a hospital with a request, so a medical
    // service that needs one is never offered for booking.
    final needsHospital = ServiceCategory.fromValue(json['category'] as String?) == ServiceCategory.medicalJordan;
    final bookable = json['isActive'] != false && json['myPrice'] != null && !needsHospital;
    return ServiceDefinitionDto(
      id: json['id'].toString(),
      category: json['category'] as String?,
      name: language.pick(ar: json['nameAr'] as String?, en: json['nameEn'] as String?),
      description: null,
      perPersonPriceAmount: json['myPrice']?.toString() ?? '0',
      availability: bookable ? 'available' : 'coming_soon',
      code: json['code'] as String?,
      slaHours: (json['slaHours'] as num?)?.toInt(),
      requiresApproval: json['requiresManagementApproval'] == true,
      fields: ServiceFieldMapper.fromJson(json['fields'] as List<dynamic>?, language),
      documents: [
        for (final d in (json['documents'] as List<dynamic>? ?? const []))
          if (d is Map<String, dynamic>)
            ServiceDocumentRequirement(
              id: d['id'].toString(),
              key: d['documentKey'] as String? ?? '',
              label: language.pick(ar: d['labelAr'] as String?, en: d['labelEn'] as String?),
              required: d['required'] == true,
            ),
      ],
    );
  }

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

  final String? code;
  final int? slaHours;
  final bool requiresApproval;
  final List<DynamicFormField> fields;
  final List<ServiceDocumentRequirement> documents;

  ServiceDefinition toEntity() => ServiceDefinition(
        id: id,
        category: ServiceCategory.fromValue(category),
        name: name,
        description: description ?? '',
        perPersonPriceCents: MoneyParser.centsFromDecimalString(perPersonPriceAmount),
        availability: availability == 'available'
            ? ServiceAvailability.available
            : ServiceAvailability.comingSoon,
        code: code,
        slaHours: slaHours,
        requiresApproval: requiresApproval,
        fields: fields,
        documents: documents,
      );
}
