// Features the API does not have say so (and offer no retry that can never work):
// the real data sources answer `unsupported_operation`, and the cubits behind the
// screens turn that into an "unavailable" state, not a generic failure.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:seen_booking/core/config/debug_fallbacks.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/error/unsupported.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/manifest/data/datasources/manifest_data_source.dart';
import 'package:seen_booking/features/manifest/domain/entities/manifest.dart';
import 'package:seen_booking/features/manifest/domain/repositories/manifest_repository.dart';
import 'package:seen_booking/features/manifest/presentation/bloc/manifest_build_cubit.dart';
import 'package:seen_booking/features/manifest/presentation/screens/manifest_build_screen.dart';
import 'package:seen_booking/features/services/data/datasources/service_interest_data_source.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_interest_cubit.dart';

class _NoPicker implements ManifestImportPicker {
  @override
  Future<Either<Failure, ManifestImportFile?>> pick() async => const Right(null);
}

void main() {
  // Whatever the suite default is, these checks are about the real behavior (no fallbacks).
  setUp(() => DebugFallbacks.testOverride = false);
  tearDown(() => DebugFallbacks.testOverride = null);

  test('isUnsupportedFailure is true only for the unsupported code', () {
    expect(isUnsupportedFailure(const ServerFailure('x', code: unsupportedOperationCode)), isTrue);
    expect(isUnsupportedFailure(const ServerFailure('x', code: 'other')), isFalse);
    expect(isUnsupportedFailure(const NetworkFailure('x')), isFalse);
  });

  test('the manifest build cubit reports "unsupported", not a retryable failure', () async {
    final cubit = ManifestBuildCubit(const ManifestRemoteDataSource(), _NoPicker(), serviceId: 's', serviceLabel: 'x');
    await cubit.load();
    expect(cubit.state.load, ManifestLoad.failure);
    expect(cubit.state.unsupported, isTrue);
    await cubit.close();
  });

  test('"notify me" is unavailable (not "try again") when the API has no such operation', () async {
    final cubit = ServiceInterestCubit(ServiceInterestRepositoryImpl(), serviceKey: 'hotels');
    await cubit.notify();
    expect(cubit.state.status, InterestStatus.unavailable);
    await cubit.close();
  });

  testWidgets('the manifest screen says it is not available and has no retry button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: ManifestBuildScreen(
        serviceId: 's',
        serviceLabel: 'x',
        createCubit: () => ManifestBuildCubit(const ManifestRemoteDataSource(), _NoPicker(), serviceId: 's', serviceLabel: 'x'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('هذه الميزة غير متاحة بعد.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });
}
