import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/services/data/models/service_field_mapper.dart';

Map<String, dynamic> _row(String key, String type, {int step = 1, int order = 0, bool required = false, Object? rules}) => {
      'id': 'def-$key',
      'stepNumber': step,
      'fieldKey': key,
      'labelAr': 'ع-$key',
      'labelEn': 'en-$key',
      'fieldType': type,
      'required': required,
      'displayOrder': order,
      'isSensitive': false,
      'validationRules': '{}',
      'effectiveRules': rules is String ? rules : jsonEncode(rules ?? {}),
    };

void main() {
  final en = AppLanguage('en');

  test('orders by step then display order and keeps the server ids', () {
    final fields = ServiceFieldMapper.fromJson([
      _row('c', 'text', step: 2, order: 1),
      _row('b', 'text', step: 1, order: 2),
      _row('a', 'text', step: 1, order: 1),
    ], en);
    expect(fields.map((f) => f.key), ['a', 'b', 'c']);
    expect(fields.first.definitionId, 'def-a');
    expect(fields.last.step, 2);
  });

  test('picks the label in the app language', () {
    final raw = [_row('a', 'text')];
    expect(ServiceFieldMapper.fromJson(raw, en).single.label, 'en-a');
    expect(ServiceFieldMapper.fromJson(raw, AppLanguage('ar')).single.label, 'ع-a');
  });

  test('maps types; unknown renders as text and file is dropped', () {
    final fields = ServiceFieldMapper.fromJson([
      _row('d', 'date'),
      _row('s', 'select'),
      _row('p', 'phone'),
      _row('x', 'hologram'),
      _row('f', 'file'),
    ], en);
    expect(fields.map((f) => f.type), [FieldType.date, FieldType.select, FieldType.phone, FieldType.text]);
  });

  test('reads rules, options and conditions', () {
    final field = ServiceFieldMapper.fromJson([
      _row('k', 'select', required: true, rules: {
        'min_length': 2,
        'max_length': 80,
        'options': [
          {'value': 'x', 'label_en': 'Ex', 'label_ar': 'إكس'},
          {'value': 'y'},
        ],
        'date_not_future': true,
        'min_valid_months': 6,
        'min_age_years': 0,
        'max_age_years': 120,
        'show_if': {'field': 'other', 'op': 'in', 'value': ['a', 'b']},
        'required_if': {'field': 'other', 'op': 'filled'},
      }),
    ], en).single;
    expect(field.required, isTrue);
    expect(field.minLength, 2);
    expect(field.maxLength, 80);
    expect(field.options!.map((o) => o.label), ['Ex', 'y']);
    expect(field.dateNotFuture, isTrue);
    expect(field.minValidMonths, 6);
    expect(field.minAgeYears, isNull);
    expect(field.maxAgeYears, 120);
    expect(field.showIf!.values, ['a', 'b']);
    expect(field.requiredIf!.op, 'filled');
  });

  test('malformed or empty rules mean no rules', () {
    final fields = ServiceFieldMapper.fromJson([
      _row('a', 'text', rules: '{not json'),
      _row('b', 'text', rules: ''),
    ], en);
    expect(fields, hasLength(2));
    expect(fields.every((f) => f.showIf == null && f.minLength == null), isTrue);
  });
}
