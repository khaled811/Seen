import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/utils/masking.dart';
import '../../domain/entities/sensitive_value.dart';
import '../../domain/repositories/sensitive_values_repository.dart';

/// `request(id) { travelers { fieldValues } }` for which values are sensitive, and the audited
/// `revealFieldValue(fieldValueId)`.
///
/// A value the server already masks is shown as sent. A sensitive value that arrives in clear
/// text is masked here and the clear text dropped, so it never leaves this method.
class SensitiveValuesRemoteDataSource implements SensitiveValuesRepository {
  SensitiveValuesRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _valuesDoc = gql(r'''
    query RequestSensitiveValues($id: ID!) {
      request(id: $id) {
        travelers {
          id
          fieldValues {
            id
            value
            isMasked
            fieldDefinition { fieldKey labelAr labelEn isSensitive displayOrder }
          }
        }
      }
    }
  ''');

  static final _revealDoc = gql(r'''
    mutation RevealFieldValue($id: ID!) { revealFieldValue(fieldValueId: $id) }
  ''');

  static String _mask(String fieldKey, String value) {
    final key = fieldKey.toLowerCase();
    if (key.contains('email') || key.contains('mail')) {
      return Masking.email(value);
    }
    if (key.contains('phone') || key.contains('mobile')) {
      return Masking.phone(value);
    }
    return Masking.keepLast4(value);
  }

  @override
  Future<Either<Failure, List<TravelerSensitive>>> forRequest(String requestId) =>
      _graphQL.query<List<TravelerSensitive>>(QueryOptions<List<TravelerSensitive>>(
        document: _valuesDoc,
        variables: {'id': requestId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) {
          final request = j['request'] as Map<String, dynamic>?;
          return [
            for (final t in (request?['travelers'] as List<dynamic>? ?? const []))
              TravelerSensitive(
                travelerId: (t as Map<String, dynamic>)['id'].toString(),
                values: _sensitiveValues(t['fieldValues'] as List<dynamic>? ?? const []),
              ),
          ];
        },
      ));

  List<SensitiveValue> _sensitiveValues(List<dynamic> raw) {
    Map<String, dynamic> definition(Map<String, dynamic> v) => v['fieldDefinition'] as Map<String, dynamic>;
    final sensitive = [
      for (final v in raw.cast<Map<String, dynamic>>())
        if (definition(v)['isSensitive'] == true) v,
    ]..sort((a, b) => ((definition(a)['displayOrder'] as num?) ?? 0).compareTo((definition(b)['displayOrder'] as num?) ?? 0));
    return [
      for (final v in sensitive)
        SensitiveValue(
          id: v['id'].toString(),
          label: _language.pick(ar: definition(v)['labelAr'] as String?, en: definition(v)['labelEn'] as String?),
          masked: v['isMasked'] == true
              ? (v['value'] as String? ?? '')
              : _mask(definition(v)['fieldKey'] as String? ?? '', v['value'] as String? ?? ''),
        ),
    ];
  }

  @override
  Future<Either<Failure, String>> reveal(String valueId) => _graphQL.mutate<String>(MutationOptions<String>(
        document: _revealDoc,
        variables: {'id': valueId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['revealFieldValue'] as String,
      ));
}
