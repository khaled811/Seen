// Sensitive traveler values against the contract: the documents are validated against
// `docs/api/mobile-api-reference.md`, only sensitive fields are kept, a clear text from the
// server is masked at once, and the reveal sends the value id.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/requests/data/datasources/sensitive_values_remote_data_source.dart';
import 'package:seen_booking/features/requests/domain/entities/sensitive_value.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, Object?> _value(String id, String key, String value, {bool masked = true, bool sensitive = true, int order = 1}) => {
      'id': id,
      'value': value,
      'isMasked': masked,
      'fieldDefinition': {'fieldKey': key, 'labelAr': 'ع-$key', 'labelEn': 'en-$key', 'isSensitive': sensitive, 'displayOrder': order},
    };

void main() {
  test('keeps only the sensitive fields, in display order, and shows a server-masked value as sent', () async {
    final graphql = ScriptedGraphQLService({
      'RequestSensitiveValues': {
        'request': {
          'travelers': [
            {
              'id': 't1',
              'fieldValues': [
                _value('f-name', 'full_name', 'Sara A.', sensitive: false, order: 1),
                _value('f-phone', 'phone', '+966 5•• ••• 214', order: 3),
                _value('f-pass', 'passport_number', '••••••4821', order: 2),
              ],
            },
          ],
        },
      },
    });
    final source = SensitiveValuesRemoteDataSource(graphQLService: graphql, language: AppLanguage('en'));
    final travelers = ((await source.forRequest('r1')) as Right).value as List<TravelerSensitive>;
    expect(travelers.single.travelerId, 't1');
    expect(travelers.single.values.map((v) => (v.id, v.label, v.masked)), [
      ('f-pass', 'en-passport_number', '••••••4821'),
      ('f-phone', 'en-phone', '+966 5•• ••• 214'),
    ]);
    expect(graphql.where('RequestSensitiveValues').single.variables, {'id': 'r1'});
  });

  test('a sensitive value that arrives in clear text is masked and the clear text is dropped', () async {
    final source = SensitiveValuesRemoteDataSource(
      graphQLService: ScriptedGraphQLService({
        'RequestSensitiveValues': {
          'request': {
            'travelers': [
              {
                'id': 't1',
                'fieldValues': [
                  _value('f-pass', 'passport_number', 'N08494821', masked: false, order: 1),
                  _value('f-mail', 'email', 'sara.a@mail.com', masked: false, order: 2),
                  _value('f-tel', 'mobile', '+966512345214', masked: false, order: 3),
                ],
              },
            ],
          },
        },
      }),
      language: AppLanguage('ar'),
    );
    final values = (((await source.forRequest('r1')) as Right).value as List<TravelerSensitive>).single.values;
    expect(values.map((v) => v.masked), ['••••••4821', 'sa•••••@mail.com', '+966 5•• ••• 214']);
    expect(values.map((v) => v.label), ['ع-passport_number', 'ع-email', 'ع-mobile']);
    for (final v in values) {
      expect(v.masked, isNot(contains('N08494821')));
      expect(v.masked, isNot(contains('sara.a@')));
    }
  });

  test('an unknown request yields no travelers; the reveal sends the value id and returns the clear text', () async {
    final graphql = ScriptedGraphQLService({
      'RequestSensitiveValues': {'request': null},
      'RevealFieldValue': {'revealFieldValue': 'N08494821'},
    });
    final source = SensitiveValuesRemoteDataSource(graphQLService: graphql, language: AppLanguage('ar'));
    expect(((await source.forRequest('nope')) as Right).value, isEmpty);
    expect(((await source.reveal('f-pass')) as Right).value, 'N08494821');
    expect(graphql.where('RevealFieldValue').single.variables, {'id': 'f-pass'});
  });
}
