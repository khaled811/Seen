// Loaded-state golden of the traveler form (design/gaps SPEC §0.2: the only addition is the
// "scan the passport" button above the first field). The baseline was captured BEFORE the screen
// was edited; the form must look the same apart from that button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';

import '../support/booking_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

class _Services implements ServicesRepository {
  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async => const Right([bookingTestService]);
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await loadAppFonts();
    InjectionContainer.instance.init();
  });

  testGoldens('traveler form', (tester) async {
    final flow = FakeBookingFlowRepository();
    final bloc = ServiceBookingBloc(
      getAvailableServicesUseCase: GetAvailableServicesUseCase(_Services()),
      createDraftUseCase: CreateDraftRequestUseCase(flow),
      addTravelersUseCase: AddTravelersUseCase(flow),
      uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
      reviewDraftUseCase: ReviewDraftUseCase(flow),
      submitDraftUseCase: SubmitDraftRequestUseCase(flow),
      getRequestDetailUseCase: GetRequestDetailUseCase(FakeBookingRequestsRepository()),
      validator: ServiceSelectionScreen.buildValidator(_l10n),
      referenceRetryDelay: Duration.zero,
    )..add(const ServiceSelected(service: bookingTestService));
    addTearDown(() => bloc.close().ignore());
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: BlocProvider.value(value: bloc, child: const TravelerEntryScreen(createPrefill: noPrefillCubit)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await screenMatchesGolden(tester, 'traveler_form');
  });
}
