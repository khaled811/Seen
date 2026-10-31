// Booking flow (Figma 08-10): catalog, traveler entry, review gating and the
// full path to the success screen, driven by the real ServiceBookingBloc with
// fake repositories (no network). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';
import '../../../support/booking_fakes.dart';

const _passportFields = [
  DynamicFormField(key: 'fullName', definitionId: 'f1', type: FieldType.text, label: 'الاسم الكامل', required: true, minLength: 2, maxLength: 100),
  DynamicFormField(key: 'passportNumber', definitionId: 'f2', type: FieldType.text, label: 'رقم الجواز', required: true, minLength: 6, maxLength: 20),
  DynamicFormField(
    key: 'nationality',
    definitionId: 'f3',
    type: FieldType.select,
    label: 'الجنسية',
    required: true,
    options: [FieldOption(value: 'يمني', label: 'يمني')],
  ),
  DynamicFormField(key: 'birthDate', definitionId: 'f4', type: FieldType.date, label: 'تاريخ الميلاد', required: true, dateNotFuture: true),
  DynamicFormField(key: 'passportIssueDate', definitionId: 'f5', type: FieldType.date, label: 'تاريخ إصدار الجواز', required: true, dateNotFuture: true),
  DynamicFormField(
    key: 'passportExpiryDate',
    definitionId: 'f6',
    type: FieldType.date,
    label: 'تاريخ انتهاء الجواز',
    required: true,
    minValidMonths: 6,
  ),
];

const _passportDocument = ServiceDocumentRequirement(id: 'd1', key: 'passport', label: 'نسخة جواز السفر', required: true);

const _nationalSecurity = ServiceDefinition(
  id: 's1',
  category: ServiceCategory.egyptNationalSecurity,
  name: 'موافقة الأمن الوطني',
  description: 'موافقة دخول مصر',
  perPersonPriceCents: 8500,
  availability: ServiceAvailability.available,
  fields: _passportFields,
  documents: [_passportDocument],
);
const _military = ServiceDefinition(
  id: 's2',
  category: ServiceCategory.egyptMilitaryIntelligence,
  name: 'موافقة الاستخبارات العسكرية',
  description: 'موافقة خاصة',
  perPersonPriceCents: 20000,
  availability: ServiceAvailability.available,
  fields: _passportFields,
);
const _airline = ServiceDefinition(
  id: 's3',
  category: ServiceCategory.egyptAirlineCircular,
  name: 'تعميم شركات الطيران',
  description: 'قريبًا',
  perPersonPriceCents: 5000,
  availability: ServiceAvailability.comingSoon,
);

class _FakeServicesRepository implements ServicesRepository {
  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async =>
      const Right([_nationalSecurity, _military, _airline]);
}

class _Made {
  _Made(this.bloc, this.flow, this.requests);

  final ServiceBookingBloc bloc;
  final FakeBookingFlowRepository flow;
  final FakeBookingRequestsRepository requests;
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

_Made _makeBloc() {
  final flow = FakeBookingFlowRepository()
    ..reviewResult = Right(bookingTestReview(travelerName: 'AHMED SALEH', serviceName: 'موافقة الأمن الوطني'));
  final requests = FakeBookingRequestsRepository();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final bloc = ServiceBookingBloc(
    getAvailableServicesUseCase: GetAvailableServicesUseCase(_FakeServicesRepository()),
    createDraftUseCase: CreateDraftRequestUseCase(flow),
    addTravelersUseCase: AddTravelersUseCase(flow),
    uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
    reviewDraftUseCase: ReviewDraftUseCase(flow),
    submitDraftUseCase: SubmitDraftRequestUseCase(flow),
    getRequestDetailUseCase: GetRequestDetailUseCase(requests),
    validator: ServiceSelectionScreen.buildValidator(l10n),
    referenceRetryDelay: Duration.zero,
  );
  return _Made(bloc, flow, requests);
}

void _select(ServiceBookingBloc bloc, ServiceDefinition service) => bloc.add(ServiceSelected(service: service));

void _fillTraveler(ServiceBookingBloc bloc, int index) {
  final values = <String, Object?>{
    'fullName': 'AHMED SALEH',
    'passportNumber': 'A1234567',
    'nationality': 'يمني',
    'birthDate': DateTime(1990, 5, 1),
    'passportIssueDate': DateTime(2020, 5, 1),
    'passportExpiryDate': DateTime(2035, 5, 1),
  };
  values.forEach((k, v) => bloc.add(TravelerFieldChanged(travelerIndex: index, fieldKey: k, value: v)));
}

Future<void> _size(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('catalog', () {
    Future<ServiceBookingBloc> pumpCatalog(WidgetTester tester) async {
      await _size(tester);
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore()); // not awaited: close() stalls under fake async
      await tester.pumpWidget(_app(BlocProvider.value(
        value: made.bloc,
        child: const Scaffold(body: ServiceCatalogView(services: [_nationalSecurity, _military, _airline])),
      )));
      await tester.pump();
      return made.bloc;
    }

    testWidgets('lists every service under one section, marks the unavailable one as soon, shows the support card',
        (tester) async {
      await pumpCatalog(tester);
      expect(find.text('الموافقات والسفر'), findsOneWidget);
      expect(find.text('تعميم شركات الطيران'), findsOneWidget);
      expect(find.text('موافقة الأمن الوطني'), findsOneWidget);
      expect(find.text('قريبًا'), findsOneWidget);
      expect(find.text('لم تجد الخدمة؟'), findsOneWidget);
    });

    testWidgets('search filters live; no match shows the empty copy', (tester) async {
      await pumpCatalog(tester);
      await tester.enterText(find.byType(TextField), 'عسكرية');
      await tester.pump();
      expect(find.text('موافقة الاستخبارات العسكرية'), findsOneWidget);
      expect(find.text('موافقة الأمن الوطني'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('لا توجد خدمات مطابقة'), findsOneWidget);
    });

    testWidgets('tapping a bookable tile starts a booking; the soon tile does not start one (it opens the coming-soon sheet)', (tester) async {
      final bloc = await pumpCatalog(tester);
      await tester.tap(find.text('تعميم شركات الطيران'), warnIfMissed: false);
      await tester.pump();
      expect(bloc.state, isNot(isA<ServiceBookingInProgress>()));

      await tester.tap(find.text('موافقة الأمن الوطني'));
      await tester.pump();
      expect(bloc.state, isA<ServiceBookingInProgress>());
      expect((bloc.state as ServiceBookingInProgress).service.id, 's1');
    });
  });

  group('traveler entry and review', () {
    Future<_Made> pumpTravelers(WidgetTester tester, {ServiceDefinition service = _nationalSecurity}) async {
      await _size(tester);
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore()); // not awaited: close() stalls under fake async
      _select(made.bloc, service);
      await tester.pumpWidget(_app(BlocProvider.value(value: made.bloc, child: const TravelerEntryScreen(createPrefill: noPrefillCubit))));
      await tester.pumpAndSettle();
      return made;
    }

    testWidgets('shows the step header, stepper, traveler card and the upload slot', (tester) async {
      await pumpTravelers(tester);
      expect(find.text('الخطوة ٢ من ٣'), findsOneWidget);
      for (final label in ['الخدمة', 'المسافرون', 'المراجعة']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('المسافر ١ من ١'), findsOneWidget);
      expect(find.text('جديد'), findsOneWidget); // empty traveler state chip
      expect(find.text('نسخة جواز السفر'), findsOneWidget);
      expect(find.text('إزالة المسافر'), findsNothing); // only one traveler
    });

    testWidgets('Next with empty fields shows required errors and flags the traveler', (tester) async {
      await pumpTravelers(tester);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
      expect(find.text('بيانات ناقصة'), findsOneWidget);
    });

    testWidgets('add and remove a traveler', (tester) async {
      await pumpTravelers(tester);
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      expect(find.text('المسافر ٢ من ٢'), findsOneWidget);
      expect(find.text('إزالة هذا المسافر'), findsOneWidget);

      await tester.ensureVisible(find.text('إزالة هذا المسافر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إزالة هذا المسافر'));
      await tester.pumpAndSettle();
      expect(find.text('المسافر ١ من ١'), findsOneWidget);
    });

    testWidgets('typing in a field reaches the bloc; a date value renders as yyyy / MM / dd', (tester) async {
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore()); // not awaited: close() stalls under fake async
      await _size(tester);
      _select(made.bloc, _nationalSecurity);
      await tester.pumpWidget(_app(BlocProvider.value(value: made.bloc, child: const TravelerEntryScreen(createPrefill: noPrefillCubit))));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'AHMED SALEH');
      await tester.pump();
      expect((made.bloc.state as ServiceBookingInProgress).travelers.first.fieldValues['fullName'], 'AHMED SALEH');

      made.bloc.add(TravelerFieldChanged(travelerIndex: 0, fieldKey: 'birthDate', value: DateTime(1990, 5, 1)));
      await tester.pumpAndSettle();
      expect(find.text('1990 / 05 / 01'), findsOneWidget);
    });

    testWidgets('valid travelers go to review; submit stays off until confirmed, then reaches success', (tester) async {
      final made = await pumpTravelers(tester);
      final bloc = BlocProvider.of<ServiceBookingBloc>(tester.element(find.byType(TravelerEntryScreen)));
      _fillTraveler(bloc, 0);
      await tester.pumpAndSettle();

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Review (step 3 of 3)
      expect(find.text('الخطوة ٣ من ٣'), findsOneWidget);
      expect(find.text('موافقة الأمن الوطني'), findsWidgets);
      expect(find.text('AHMED SALEH'), findsOneWidget);
      expect(find.textContaining('سيتم حجز'), findsOneWidget);
      expect(find.text('المتاح بعد الحجز'), findsOneWidget);

      final submit = find.widgetWithText(SeenButton, 'تأكيد وإرسال الطلب');
      expect(tester.widget<SeenButton>(submit).onPressed, isNull);

      await tester.tap(find.text('أؤكد صحة البيانات والمستندات المرفقة'));
      await tester.pump();
      expect(tester.widget<SeenButton>(submit).onPressed, isNotNull);

      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(made.flow.created, ['s1']);
      expect(made.flow.submitted, ['req-1']);
      expect(find.text(lookupAppLocalizations(const Locale('ar')).bookingSuccessTitle), findsOneWidget);
    });
  });

  group('SYS-09 passport 6-month rule', () {
    Future<ServiceBookingBloc> pump(WidgetTester tester, {int travelers = 1}) async {
      await _size(tester);
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore());
      _select(made.bloc, _nationalSecurity);
      for (var i = 1; i < travelers; i++) {
        made.bloc.add(const TravelerAdded());
      }
      await tester.pumpWidget(_app(BlocProvider.value(value: made.bloc, child: const TravelerEntryScreen(createPrefill: noPrefillCubit))));
      await tester.pumpAndSettle();
      return made.bloc;
    }

    void setExpiry(ServiceBookingBloc bloc, int index, DateTime d) =>
        bloc.add(TravelerFieldChanged(travelerIndex: index, fieldKey: 'passportExpiryDate', value: d));

    testWidgets('an expiry under 6 months shows the rule, the error, and blocks Next', (tester) async {
      final bloc = await pump(tester);
      _fillTraveler(bloc, 0);
      setExpiry(bloc, 0, DateTime.now().add(const Duration(days: 60)));
      await tester.pumpAndSettle();
      expect(find.text('قاعدة الـ ٦ أشهر'), findsOneWidget);
      expect(find.textContaining('أقل من ٦ أشهر من تاريخ السفر'), findsOneWidget);
      expect(find.text('≥ ٦ أشهر · مقبول'), findsOneWidget);
      final next = tester.widget<SeenButton>(find.widgetWithText(SeenButton, 'التالي'));
      expect(next.onPressed, isNull);
    });

    testWidgets('a valid expiry shows no rule and Next works', (tester) async {
      final bloc = await pump(tester);
      _fillTraveler(bloc, 0);
      await tester.pumpAndSettle();
      expect(find.text('قاعدة الـ ٦ أشهر'), findsNothing);
      final next = tester.widget<SeenButton>(find.widgetWithText(SeenButton, 'التالي'));
      expect(next.onPressed, isNotNull);
    });

    testWidgets('with several travelers the blocked one can be removed from the bar', (tester) async {
      final bloc = await pump(tester, travelers: 2);
      _fillTraveler(bloc, 0);
      _fillTraveler(bloc, 1);
      setExpiry(bloc, 1, DateTime.now().add(const Duration(days: 30)));
      bloc.add(const ActiveTravelerChanged(1));
      await tester.pumpAndSettle();
      expect(find.text('إزالة المسافر'), findsOneWidget);
      await tester.tap(find.text('إزالة المسافر'));
      await tester.pumpAndSettle();
      expect((bloc.state as ServiceBookingInProgress).travelers, hasLength(1));
      expect(find.text('قاعدة الـ ٦ أشهر'), findsNothing);
    });

    testWidgets('a future issue date is flagged as the user types', (tester) async {
      final bloc = await pump(tester);
      _fillTraveler(bloc, 0);
      bloc.add(TravelerFieldChanged(travelerIndex: 0, fieldKey: 'passportIssueDate', value: DateTime.now().add(const Duration(days: 90))));
      await tester.pumpAndSettle();
      expect(find.textContaining('تاريخ الإصدار في المستقبل'), findsOneWidget);
    });
  });
}
