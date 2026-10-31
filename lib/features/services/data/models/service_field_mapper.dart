import 'dart:convert';

import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../../dynamic_forms/domain/entities/field_condition.dart';

/// Turns a service's `fields` (contract 10.2 "Dynamic forms") into the form
/// engine's [DynamicFormField]s.
///
/// `effectiveRules` is a JSON *string* of hints; a malformed one is treated as
/// "no rules" (the server validates anyway). An unknown `fieldType` renders as
/// plain text. A `file` field is not a form input (uploads follow the service's
/// `documents`), so it is dropped here.
abstract final class ServiceFieldMapper {
  static List<DynamicFormField> fromJson(List<dynamic>? raw, AppLanguage language) {
    final rows = <Map<String, dynamic>>[
      for (final item in raw ?? const []) if (item is Map<String, dynamic>) item,
    ]..sort((a, b) {
        final byStep = _int(a['stepNumber']).compareTo(_int(b['stepNumber']));
        return byStep != 0 ? byStep : _int(a['displayOrder']).compareTo(_int(b['displayOrder']));
      });
    return [
      for (final row in rows)
        if (row['fieldType'] != 'file') _field(row, language),
    ];
  }

  static DynamicFormField _field(Map<String, dynamic> row, AppLanguage language) {
    final rules = _rules(row['effectiveRules']);
    final type = switch (row['fieldType']) {
      'date' => FieldType.date,
      'select' => FieldType.select,
      'phone' => FieldType.phone,
      _ => FieldType.text,
    };
    final options = type == FieldType.select ? _options(rules['options'], language) : null;
    return DynamicFormField(
      key: row['fieldKey'] as String,
      definitionId: row['id']?.toString(),
      step: _int(row['stepNumber'], 1),
      type: type,
      label: language.pick(ar: row['labelAr'] as String?, en: row['labelEn'] as String?),
      required: row['required'] == true,
      minLength: _intOrNull(rules['min_length']),
      maxLength: _intOrNull(rules['max_length']),
      min: _numOrNull(rules['min_value']),
      max: _numOrNull(rules['max_value']),
      format: rules['format'] is String ? rules['format'] as String : null,
      options: options,
      showIf: _condition(rules['show_if']),
      requiredIf: _condition(rules['required_if']),
      dateNotFuture: rules['date_not_future'] == true,
      dateNotPast: rules['date_not_past'] == true,
      minValidMonths: _positive(rules['min_valid_months']),
      minAgeYears: _positive(rules['min_age_years']),
      // The contract example lists 120 as a ceiling; any positive value applies.
      maxAgeYears: _positive(rules['max_age_years']),
    );
  }

  static Map<String, dynamic> _rules(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is! String || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  static List<FieldOption>? _options(Object? raw, AppLanguage language) {
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map<String, dynamic> && item['value'] != null)
          FieldOption(
            value: item['value'].toString(),
            label: language.pick(ar: item['label_ar'] as String?, en: item['label_en'] as String?).ifEmpty(item['value'].toString()),
          ),
    ];
  }

  static FieldCondition? _condition(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['field'] is! String || raw['op'] is! String) return null;
    final value = raw['value'];
    return FieldCondition(
      field: raw['field'] as String,
      op: raw['op'] as String,
      values: switch (value) {
        null => const [],
        List() => [for (final v in value) v.toString()],
        _ => [value.toString()],
      },
    );
  }

  static int _int(Object? v, [int fallback = 0]) => _intOrNull(v) ?? fallback;
  static int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
  static num? _numOrNull(Object? v) => v is num ? v : null;

  /// A rule value of 0 (or a missing one) means "no rule".
  static int? _positive(Object? v) {
    final n = _intOrNull(v);
    return n != null && n > 0 ? n : null;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
