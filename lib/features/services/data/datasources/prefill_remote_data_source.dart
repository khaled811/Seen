import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/prefill.dart';
import '../../domain/repositories/prefill_repository.dart';

/// `prefillCandidates` and `prefillFromRequest` (`docs/api/mobile-api-reference.md`).
class PrefillRemoteDataSource implements PrefillRepository {
  PrefillRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _candidatesDoc = gql(r'''
    query PrefillCandidates($serviceTypeId: ID!) {
      prefillCandidates(serviceTypeId: $serviceTypeId) { requestId referenceCode serviceNameAr serviceNameEn createdAt travelerCount }
    }
  ''');

  static final _valuesDoc = gql(r'''
    mutation PrefillFromRequest($serviceTypeId: ID!, $sourceRequestId: ID!) {
      prefillFromRequest(serviceTypeId: $serviceTypeId, sourceRequestId: $sourceRequestId) { travelers }
    }
  ''');

  @override
  Future<Either<Failure, List<PrefillCandidate>>> candidates(String serviceId) => _graphQL.query<List<PrefillCandidate>>(
        QueryOptions<List<PrefillCandidate>>(
          document: _candidatesDoc,
          variables: {'serviceTypeId': serviceId},
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => [
            for (final c in (j['prefillCandidates'] as List<dynamic>).cast<Map<String, dynamic>>())
              PrefillCandidate(
                requestId: c['requestId'] as String,
                referenceCode: c['referenceCode'] as String? ?? '',
                serviceName: _language.pick(ar: c['serviceNameAr'] as String?, en: c['serviceNameEn'] as String?),
                travelerCount: (c['travelerCount'] as num?)?.toInt() ?? 0,
                createdAt: DateTime.tryParse(c['createdAt'] as String? ?? '')?.toLocal(),
              ),
          ],
        ),
      );

  @override
  Future<Either<Failure, PrefillValues>> valuesFrom({required String serviceId, required String sourceRequestId}) =>
      _graphQL.mutate<PrefillValues>(
        MutationOptions<PrefillValues>(
          document: _valuesDoc,
          variables: {'serviceTypeId': serviceId, 'sourceRequestId': sourceRequestId},
          fetchPolicy: FetchPolicy.noCache,
          parserFn: (j) => parseTravelers((j['prefillFromRequest'] as Map<String, dynamic>)['travelers']),
        ),
      );

  /// `travelers` is free JSON: each traveler is read as `{fieldKey: value}`, or as a
  /// list of `{key | fieldKey, value}` pairs. Anything else (and any empty value) is
  /// dropped; every value becomes text, dates stay `YYYY-MM-DD`.
  static PrefillValues parseTravelers(Object? raw) {
    final travelers = <Map<String, String>>[];
    if (raw is List) {
      for (final t in raw) {
        final values = <String, String>{};
        void put(Object? key, Object? value) {
          final k = key?.toString();
          final v = value is Map || value is List ? null : value?.toString();
          if (k != null && k.isNotEmpty && v != null && v.trim().isNotEmpty) values[k] = v;
        }

        if (t is Map) {
          t.forEach(put);
        } else if (t is List) {
          for (final pair in t) {
            if (pair is Map) put(pair['key'] ?? pair['fieldKey'], pair['value']);
          }
        }
        travelers.add(values);
      }
    }
    return PrefillValues(travelers);
  }
}
