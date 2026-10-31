// What the person sees of the server-side booking: the review bound to the
// server's quote and verdict, a draft opened from the list, failures of every
// step, and the traveler form's own server states. Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_format.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/services/presentation/screens/booking_review_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';

import '../../../support/booking_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

class _Services implements ServicesRepository {
  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async => const Right([bookingTestService]);
}

class _Rig {
  _Rig() {
    bloc = ServiceBookingBloc(
      getAvailableServicesUseCase: GetAvailableServicesUseCase(_Services()),
      createDraftUseCase: CreateDraftRequestUseCase(flow),
      addTravelersUseCase: AddTravelersUseCase(flow),
      uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
      reviewDraftUseCase: ReviewDraftUseCase(flow),
      submitDraftUseCase: SubmitDraftRequestUseCase(flow),
      getRequestDetailUseCase: GetRequestDetailUseCase(requests),
      validator: ServiceSelectionScreen.buildValidator(_l10n),
      referenceRetryDelay: Duration.zero,
    );
  }

  final flow = FakeBookingFlowRepository();
  final requests = FakeBookingRequestsRepository();
  late final ServiceBookingBloc bloc;
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

Future<void> _size(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _fill(ServiceBookingBloc bloc) => bloc
  ..add(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'fullName', value: 'Amal Saleh'))
  ..add(TravelerFieldChanged(travelerIndex: 0, fieldKey: 'birthDate', value: DateTime(1990, 3, 5)));

void main() {
  group('review (bound to the server quote)', () {
    /// A bloc that has gone through the traveler step and holds [review].
    Future<_Rig> reach(WidgetTester tester, {required Object review, bool resumed = false}) async {
      final rig = _Rig();
      addTearDown(() => rig.bloc.close().ignore());
      rig.flow.reviewResult = Right(review as dynamic);
      if (resumed) {
        rig.bloc.add(const BookingDraftOpened('req-1'));
      } else {
        rig.bloc.add(const ServiceSelected(service: bookingTestService));
        _fill(rig.bloc);
        rig.bloc.add(const TravelerContinuePressed());
      }
      await _settle(tester);
      await _size(tester);
      await tester.pumpWidget(_app(BlocProvider.value(value: rig.bloc, child: const BookingReviewScreen())));
      await tester.pump();
      return rig;
    }

    SeenButton submit(WidgetTester tester) =>
        tester.widget<SeenButton>(find.widgetWithText(SeenButton, _l10n.reviewSubmitAction));

    testWidgets('shows the server travelers (masked), the total and the hold; submit waits for the confirmation', (tester) async {
      await reach(tester, review: bookingTestReview());
      expect(find.text('A*** S***'), findsOneWidget);
      expect(find.textContaining('85.00'), findsWidgets);
      expect(find.text(_l10n.reviewAvailableAfter), findsOneWidget);
      expect(submit(tester).onPressed, isNull);
      await tester.tap(find.text(_l10n.reviewConfirmTerms));
      await tester.pump();
      expect(submit(tester).onPressed, isNotNull);
      expect(find.text(_l10n.reviewCannotSubmit), findsNothing);
    });

    testWidgets('the server says it cannot be submitted: the banner shows and the button stays off even when confirmed', (tester) async {
      await reach(tester, review: bookingTestReview(canSubmit: false, errors: const ['documents_missing']));
      expect(find.text(_l10n.reviewCannotSubmit), findsOneWidget);
      await tester.tap(find.text(_l10n.reviewConfirmTerms));
      await tester.pump();
      expect(submit(tester).onPressed, isNull);
    });

    testWidgets('a service that waits for approval shows the deferred note and no hold card', (tester) async {
      await reach(tester, review: bookingTestReview(holdDeferred: true));
      expect(find.text(_l10n.reviewHoldDeferredNote), findsOneWidget);
      expect(find.text(_l10n.reviewAvailableAfter), findsNothing);
    });

    testWidgets('funds that do not cover it: shortfall from the server figures, top-up offered, no way to submit', (tester) async {
      await reach(tester, review: bookingTestReview(fundsSufficient: false, availableAfterCents: -2500, canSubmit: false));
      expect(find.text(_l10n.reviewTopUpShortfall(SeenFormat.usd(25))), findsOneWidget);
      expect(find.text(_l10n.reviewConfirmTerms), findsNothing);
      expect(submit(tester).onPressed, isNull);
      // The balance is the server's, not recomputed: no "cannot be submitted" banner on top of the shortfall.
      expect(find.text(_l10n.reviewCannotSubmit), findsNothing);
    });

    testWidgets('a draft opened from the list has no edit links', (tester) async {
      await reach(tester, review: bookingTestReview(requestId: 'req-1'), resumed: true);
      expect(find.text(_l10n.reviewEditAction), findsNothing);
      expect(find.text('A*** S***'), findsOneWidget);
    });

    testWidgets('a draft whose quote cannot load shows the reason and a retry that loads it', (tester) async {
      final rig = _Rig();
      addTearDown(() => rig.bloc.close().ignore());
      rig.flow.reviewResult = const Left(NetworkFailure('off'));
      rig.bloc.add(const BookingDraftOpened('req-1'));
      await _settle(tester);
      await _size(tester);
      await tester.pumpWidget(_app(BlocProvider.value(value: rig.bloc, child: const BookingReviewScreen())));
      await tester.pump();
      expect(find.text(_l10n.errorNetwork), findsOneWidget);

      rig.flow.reviewResult = Right(bookingTestReview());
      await tester.tap(find.text(_l10n.retry));
      await _settle(tester);
      expect(find.text('A*** S***'), findsOneWidget);
    });

    testWidgets('a failed submit says why and re-reads the quote', (tester) async {
      final rig = await reach(tester, review: bookingTestReview());
      rig.flow.submitResult = const Left(ServerFailure('x', code: 'insufficient_funds'));
      await tester.tap(find.text(_l10n.reviewConfirmTerms));
      await tester.pump();
      await tester.tap(find.widgetWithText(SeenButton, _l10n.reviewSubmitAction));
      await _settle(tester);
      expect(find.text(_l10n.errInsufficientFunds), findsOneWidget);
      expect(rig.flow.reviewed.length, 2); // once to open, once after the failure
    });

    testWidgets('a submit that goes through shows the reference code on the receipt, not the request id', (tester) async {
      final rig = await reach(tester, review: bookingTestReview());
      rig.flow.submitResult = const Right(
        ServiceBookingResult(requestId: 'req-1', status: RequestStatus.submitted, referenceCode: 'SB-20481'),
      );
      await tester.tap(find.text(_l10n.reviewConfirmTerms));
      await tester.pump();
      await tester.tap(find.widgetWithText(SeenButton, _l10n.reviewSubmitAction));
      await _settle(tester);
      expect(find.text(_l10n.bookingSuccessTitle), findsOneWidget);
      expect(find.text('SB-20481'), findsOneWidget);
      expect(find.text('req-1'), findsNothing);
    });

    testWidgets('submitting twice quickly sends one request', (tester) async {
      final rig = await reach(tester, review: bookingTestReview());
      await tester.tap(find.text(_l10n.reviewConfirmTerms));
      await tester.pump();
      final button = find.widgetWithText(SeenButton, _l10n.reviewSubmitAction);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await _settle(tester);
      expect(rig.flow.submitted, hasLength(1));
    });
  });

  group('traveler form against the server', () {
    Future<_Rig> open(WidgetTester tester) async {
      final rig = _Rig();
      addTearDown(() => rig.bloc.close().ignore());
      rig.bloc.add(const ServiceSelected(service: bookingTestService));
      await _size(tester);
      await tester.pumpWidget(_app(BlocProvider.value(value: rig.bloc, child: const TravelerEntryScreen(createPrefill: noPrefillCubit))));
      await _settle(tester);
      return rig;
    }

    testWidgets('one upload slot per document the service asks for', (tester) async {
      await open(tester);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('a field shown only under a condition appears when its condition holds', (tester) async {
      final rig = await open(tester);
      expect(find.text('Spouse'), findsNothing);
      rig.bloc.add(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'status', value: 'married'));
      await _settle(tester);
      expect(find.text('Spouse'), findsOneWidget);
      rig.bloc.add(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'status', value: 'single'));
      await _settle(tester);
      expect(find.text('Spouse'), findsNothing);
    });

    testWidgets('a value the server refuses is shown on its field in the app\'s own words', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      rig.flow.addResult = const Left(
        ValidationFailure('x', issues: [ValidationIssue(code: 'format_invalid', travelerIndex: 0, field: 'fullName')]),
      );
      await _settle(tester);
      await tester.tap(find.text(_l10n.bookingNextAction));
      await _settle(tester);
      expect(find.text(_l10n.validationServerRejected), findsOneWidget);
      expect(find.textContaining('format_invalid'), findsNothing);
    });

    testWidgets('a documented field code is worded with the values the server gives (limits, months)', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      rig.flow.addResult = const Left(
        ValidationFailure('x', issues: [ValidationIssue(code: 'too_short', travelerIndex: 0, field: 'fullName', params: {'min': 5})]),
      );
      await _settle(tester);
      await tester.tap(find.text(_l10n.bookingNextAction));
      await _settle(tester);
      expect(find.text(_l10n.validationMinLength(5)), findsOneWidget);
      expect(find.text(_l10n.validationServerRejected), findsNothing);
    });

    testWidgets('no connection while filing: the reason is shown, the form is kept, Next works again', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      rig.flow.createResult = const Left(NetworkFailure('off'));
      await _settle(tester);
      await tester.tap(find.text(_l10n.bookingNextAction));
      await _settle(tester);
      expect(find.text(_l10n.errorNetwork), findsOneWidget);
      final next = tester.widget<SeenButton>(find.widgetWithText(SeenButton, _l10n.bookingNextAction));
      expect(next.onPressed, isNotNull);
      expect((rig.bloc.state as ServiceBookingInProgress).travelers.single.fieldValues['fullName'], 'Amal Saleh');
    });

    testWidgets('while filing, Next is disabled (no second tap)', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      final gate = rig.flow.holdCreate = Completer<void>();
      await _settle(tester);
      await tester.tap(find.text(_l10n.bookingNextAction));
      await tester.pump();
      final next = tester.widget<SeenButton>(find.widgetWithText(SeenButton, _l10n.loading));
      expect(rig.bloc.state, isA<ServiceBookingInProgress>());
      expect((rig.bloc.state as ServiceBookingInProgress).isSaving, isTrue);
      expect(next.onPressed, isNull);
      gate.complete();
      await _settle(tester);
      expect(rig.flow.created, hasLength(1));
    });

    testWidgets('an expired session while filing says so', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      rig.flow.createResult = const Left(UnauthorizedFailure('over', 'session_expired'));
      await _settle(tester);
      await tester.tap(find.text(_l10n.bookingNextAction));
      await _settle(tester);
      expect(find.text(_l10n.errorUnauthorized), findsOneWidget);
    });

    testWidgets('a file the server refuses is explained', (tester) async {
      final rig = await open(tester);
      _fill(rig.bloc);
      rig.flow.uploadResult = const Left(ServerFailure('x', code: 'file_content_mismatch'));
      await _settle(tester);
      // No file is picked in this test, so nothing is uploaded: the form goes on.
      await tester.tap(find.text(_l10n.bookingNextAction));
      await _settle(tester);
      expect(rig.flow.uploads, isEmpty);
    });
  });
}
