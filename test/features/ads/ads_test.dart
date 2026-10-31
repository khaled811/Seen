// The home banner comes from `activeAds`: contract-valid document, the language
// the app shows, nothing when there is no ad, and only https links are followed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/presentation/widgets/promo_banner.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/ads/data/datasources/ads_remote_data_source.dart';
import 'package:seen_booking/features/ads/domain/entities/ad_banner.dart';
import 'package:seen_booking/features/ads/domain/repositories/ads_repository.dart';
import 'package:seen_booking/features/ads/presentation/bloc/home_banner_cubit.dart';

import '../../support/scripted_graphql_service.dart';

Map<String, Object?> _ad(String id, {String link = 'https://example.com/offer', String label = 'Open'}) =>
    {'id': id, 'title': 'Eid offer', 'body': 'Visa fees waived', 'ctaLabel': label, 'ctaLink': link};

class _Repo implements AdsRepository {
  _Repo(this.results);
  final List<Either<Failure, AdBanner?>> results;
  int calls = 0;

  @override
  Future<Either<Failure, AdBanner?>> homeBanner() async => results[calls++];

  final impressions = <String>[];
  final clicks = <String>[];

  @override
  Future<Either<Failure, void>> recordImpression(String adId) async {
    impressions.add(adId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> recordClick(String adId) async {
    clicks.add(adId);
    return const Right(null);
  }
}

void main() {
  group('AdsRemoteDataSource', () {
    test('asks for the home slot in the language shown, and takes the first ad', () async {
      final graphql = ScriptedGraphQLService({
        'HomeBanner': {
          'activeAds': [_ad('a1'), _ad('a2')],
        },
      });
      final source = AdsRemoteDataSource(graphQLService: graphql, language: AppLanguage('en'));
      final ad = ((await source.homeBanner()) as Right).value as AdBanner;
      expect(graphql.where('HomeBanner').single.variables, {'locale': 'en'});
      expect((ad.id, ad.title, ad.body), ('a1', 'Eid offer', 'Visa fees waived'));
    });

    test('no ad means no banner (a pending or suspended agency gets an empty list)', () async {
      final graphql = ScriptedGraphQLService({
        'HomeBanner': {'activeAds': <Object?>[]},
      });
      expect(((await AdsRemoteDataSource(graphQLService: graphql, language: AppLanguage()).homeBanner()) as Right).value, isNull);
    });

    test('a refusal is a failure, not an empty banner', () async {
      final graphql = ScriptedGraphQLService({'HomeBanner': const ServerFailure('x', code: 'permission_denied')});
      expect((await AdsRemoteDataSource(graphQLService: graphql, language: AppLanguage()).homeBanner()).isLeft(), isTrue);
    });
  });

  group('ad counts', () {
    test('the ad data source sends impression and click with the ad id', () async {
      final graphql = ScriptedGraphQLService({
        'RecordAdImpression': {'recordAdImpression': true},
        'RecordAdClick': {'recordAdClick': true},
      });
      final source = AdsRemoteDataSource(graphQLService: graphql, language: AppLanguage());
      expect((await source.recordImpression('a1')).isRight(), isTrue);
      expect((await source.recordClick('a1')).isRight(), isTrue);
      expect(graphql.where('RecordAdImpression').single.variables, {'adId': 'a1'});
      expect(graphql.where('RecordAdClick').single.variables, {'adId': 'a1'});
    });

    test('an ad is counted as shown once per showing, not on every refresh; a tap is counted as a click', () async {
      const ad = AdBanner(id: '1', title: 't', body: 'b');
      final repo = _Repo([const Right(ad), const Right(ad), const Right(AdBanner(id: '2', title: 't', body: 'b'))]);
      final cubit = HomeBannerCubit(repo);
      await cubit.load();
      await cubit.load();
      expect(repo.impressions, ['1']);
      await cubit.load();
      expect(repo.impressions, ['1', '2']);
      cubit.clicked();
      expect(repo.clicks, ['2']);
      await cubit.close();
    });
  });

  group('AdBanner link', () {
    AdBanner ad(String link, {String label = 'Open'}) => AdBanner(id: '1', title: 't', body: 'b', ctaLabel: label, ctaLink: link);

    test('the web paths of the server map to screens of the app; anything else with a slash has none', () {
      expect(ad('/agent/wallet').internalDestination, AdDestination.wallet);
      expect(ad('/agent/services?service=3f2a').internalDestination, AdDestination.services);
      expect(ad('/agent/employees').internalDestination, AdDestination.team);
      expect(ad('/agent/wallet').hasAction, isTrue);
      expect(ad('/agent/wallet').openableLink, isNull); // opened in the app, not outside it
      for (final none in ['/agent/dashboard', '/agent/security', '/other', '//evil.example/x', 'agent/wallet']) {
        expect(ad(none).internalDestination, isNull, reason: none);
        expect(ad(none).hasAction, isFalse, reason: none);
      }
    });

    test('only an https link with a host is opened', () {
      expect(ad('https://example.com/x').hasAction, isTrue);
      for (final bad in ['http://example.com', 'javascript:alert(1)', 'tel:+967770000000', '/services', '', 'https://']) {
        expect(ad(bad).hasAction, isFalse, reason: bad);
        expect(ad(bad).openableLink, isNull, reason: bad);
      }
    });

    test('no label, no button', () => expect(ad('https://example.com', label: ' ').hasAction, isFalse));
  });

  group('HomeBannerCubit', () {
    test('shows the ad; a failed refresh keeps it; an empty answer removes it', () async {
      const first = AdBanner(id: '1', title: 't', body: 'b');
      final repo = _Repo([const Right(first), const Left(NetworkFailure('offline')), const Right(null)]);
      final cubit = HomeBannerCubit(repo);
      await cubit.load();
      expect(cubit.state.ad, first);
      await cubit.load();
      expect(cubit.state.ad, first);
      expect(cubit.state.failure, isA<NetworkFailure>());
      await cubit.load();
      expect(cubit.state.ad, isNull);
      await cubit.close();
    });

    test('two loads at once read once', () async {
      final repo = _Repo([const Right(null), const Right(null)]);
      final cubit = HomeBannerCubit(repo);
      await Future.wait([cubit.load(), cubit.load()]);
      expect(repo.calls, 1);
      await cubit.close();
    });
  });

  group('SeenPromoBanner', () {
    Future<void> show(WidgetTester tester, {String? label}) => tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: SeenPromoBanner(title: 'Eid offer', subtitle: 'Visa fees waived', actionLabel: label, onAction: () {})),
        ));

    testWidgets('shows the ad text and a button only when there is something to open', (tester) async {
      await show(tester, label: 'Open');
      expect(find.text('Eid offer'), findsOneWidget);
      expect(find.byType(SeenButton), findsOneWidget);
      await show(tester);
      expect(find.text('Visa fees waived'), findsOneWidget);
      expect(find.byType(SeenButton), findsNothing);
    });
  });
}
