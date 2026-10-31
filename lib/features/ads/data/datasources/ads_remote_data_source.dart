import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/ad_banner.dart';
import '../../domain/repositories/ads_repository.dart';

/// `activeAds(placement: "home_banner", locale:)` (`docs/api/mobile-api-reference.md`).
/// The server picks the language of `title` / `body` / `ctaLabel` from [locale].
class AdsRemoteDataSource implements AdsRepository {
  AdsRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _homeDoc = gql(r'''
    query HomeBanner($locale: String) {
      activeAds(placement: "home_banner", locale: $locale) { id title body ctaLabel ctaLink }
    }
  ''');

  static final _impressionDoc = gql(r'''
    mutation RecordAdImpression($adId: ID!) { recordAdImpression(adId: $adId) }
  ''');

  static final _clickDoc = gql(r'''
    mutation RecordAdClick($adId: ID!) { recordAdClick(adId: $adId) }
  ''');

  @override
  Future<Either<Failure, void>> recordImpression(String adId) async => (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _impressionDoc,
        variables: {'adId': adId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['recordAdImpression'] == true,
      )))
          .map((_) {});

  @override
  Future<Either<Failure, void>> recordClick(String adId) async => (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _clickDoc,
        variables: {'adId': adId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => j['recordAdClick'] == true,
      )))
          .map((_) {});

  @override
  Future<Either<Failure, AdBanner?>> homeBanner() => _graphQL.query<AdBanner?>(
        QueryOptions<AdBanner?>(
          document: _homeDoc,
          variables: {'locale': _language.code},
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) {
            final ads = (j['activeAds'] as List<dynamic>).cast<Map<String, dynamic>>();
            if (ads.isEmpty) return null;
            final a = ads.first;
            return AdBanner(
              id: a['id'] as String,
              title: a['title'] as String? ?? '',
              body: a['body'] as String? ?? '',
              ctaLabel: a['ctaLabel'] as String? ?? '',
              ctaLink: a['ctaLink'] as String? ?? '',
            );
          },
        ),
      );
}
