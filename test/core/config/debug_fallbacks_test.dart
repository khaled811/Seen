import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/config/debug_fallbacks.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/features/services/data/datasources/services_remote_data_source.dart';
import 'package:seen_booking/features/services/data/datasources/services_remote_data_source_debug_fallback.dart';

import '../../support/failing_graphql_service.dart';

void main() {
  final saved = DebugFallbacks.testOverride;
  tearDown(() => DebugFallbacks.testOverride = saved);

  group('DebugFallbacks.enabled', () {
    test('is off when the test override says off', () {
      DebugFallbacks.testOverride = false;
      expect(DebugFallbacks.enabled, isFalse);
      expect(debugFallbacksEnabled, isFalse);
    });

    test('is on only when explicitly requested (tests run with kDebugMode)', () {
      DebugFallbacks.testOverride = true;
      expect(DebugFallbacks.enabled, isTrue);
    });

    test('without an override follows the build define, which defaults to off', () {
      DebugFallbacks.testOverride = null;
      expect(DebugFallbacks.enabled, const bool.fromEnvironment('USE_DEBUG_FALLBACKS'));
    });
  });

  group('a fallback decorator over a failing transport', () {
    DebugFallbackServicesRemoteDataSource build() => DebugFallbackServicesRemoteDataSource(
          ServicesRemoteDataSourceImpl(graphQLService: const FailingGraphQLService(), language: AppLanguage()),
        );

    test('surfaces the real failure when fallbacks are off', () async {
      DebugFallbacks.testOverride = false;
      final result = await build().getAvailableServices();
      expect(result.isLeft(), isTrue);
    });

    test('substitutes demo data only when fallbacks are on', () async {
      DebugFallbacks.testOverride = true;
      final result = await build().getAvailableServices();
      expect(result.isRight(), isTrue);
    });
  });

  test('the shared test config installs a failing transport, not the network', () {
    expect(InjectionContainer.testDefaults?.graphQLService, isA<FailingGraphQLService>());
  });
}
