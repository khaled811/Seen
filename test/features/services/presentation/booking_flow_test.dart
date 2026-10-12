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
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_request.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/domain/usecases/submit_booking_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';
import 'package:seen_booking/features/services/presentation/widgets/service_traveler_fields.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

const _nationalSecurity = ServiceDefinition(
  id: 's1',
  category: ServiceCategory.egyptNationalSecurity,
  name: 'موافقة الأمن الوطني',
  description: 'موافقة دخول مصر',
  perPersonPriceCents: 8500,
  availability: ServiceAvailability.available,
);
const _military = ServiceDefinition(
  id: 's2',
  category: ServiceCategory.egyptMilitaryIntelligence,
  name: 'موافقة الاستخبارات العسكرية',
  description: 'موافقة خاصة',
  perPersonPriceCents: 20000,
  availability: ServiceAvailability.available,
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
  final submitted = <ServiceBookingRequest>[];

  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async =>
      const Right([_nationalSecurity, _military, _airline]);

  @override
  Future<Either<Failure, ServiceBookingResult>> submitBooking(ServiceBookingRequest request) async {
    submitted.add(request);
    return Right(ServiceBookingResult(
      requestId: 'SB-90001',
      status: RequestStatus.submitted,
      totalPriceCents: 8500,
      createdAt: DateTime(2026, 11, 12),
    ));
  }
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(WalletBalance(
        availableCents: 100000,
        holdCents: 0,
        creditLimitCents: 0,
        currency: WalletCurrency.usd,
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

({ServiceBookingBloc bloc, _FakeServicesRepository repo}) _makeBloc() {
  final repo = _FakeServicesRepository();
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final bloc = ServiceBookingBloc(
    getAvailableServicesUseCase: GetAvailableServicesUseCase(repo),
    submitBookingUseCase: SubmitBookingUseCase(repo),
    getWalletBalanceUseCase: GetWalletBalanceUseCase(_FakeWalletRepository()),
    validator: ServiceSelectionScreen.buildValidator(l10n),
  );
  return (bloc: bloc, repo: repo);
}

void _select(ServiceBookingBloc bloc, ServiceDefinition service) => bloc.add(ServiceSelected(
      service: service,
      travelerFields: ServiceTravelerFields.forCategory(service.category, lookupAppLocalizations(const Locale('ar'))),
    ));

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

    testWidgets('groups services, marks the unavailable one as soon, and shows the support card', (tester) async {
      await pumpCatalog(tester);
      expect(find.text('الموافقات'), findsWidgets); // chip + section header
      expect(find.text('السفر'), findsWidgets);
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

    testWidgets('a group chip narrows the list', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.widgetWithText(InkWell, 'السفر').first);
      await tester.pump();
      expect(find.text('تعميم شركات الطيران'), findsOneWidget);
      expect(find.text('موافقة الأمن الوطني'), findsNothing);
    });

    testWidgets('tapping a bookable tile starts a booking; the soon tile does nothing', (tester) async {
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
    Future<_FakeServicesRepository> pumpTravelers(WidgetTester tester, {ServiceDefinition service = _nationalSecurity}) async {
      await _size(tester);
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore()); // not awaited: close() stalls under fake async
      _select(made.bloc, service);
      await tester.pumpWidget(_app(BlocProvider.value(value: made.bloc, child: const TravelerEntryScreen())));
      await tester.pumpAndSettle();
      return made.repo;
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
      await tester.tap(find.text('إضافة مسافر'));
      await tester.pumpAndSettle();
      expect(find.text('المسافر ٢ من ٢'), findsOneWidget);
      expect(find.text('إزالة المسافر'), findsOneWidget);

      await tester.ensureVisible(find.text('إزالة المسافر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إزالة المسافر'));
      await tester.pumpAndSettle();
      expect(find.text('المسافر ١ من ١'), findsOneWidget);
    });

    testWidgets('typing in a field reaches the bloc; a date value renders as yyyy / MM / dd', (tester) async {
      final made = _makeBloc();
      addTearDown(() => made.bloc.close().ignore()); // not awaited: close() stalls under fake async
      await _size(tester);
      _select(made.bloc, _nationalSecurity);
      await tester.pumpWidget(_app(BlocProvider.value(value: made.bloc, child: const TravelerEntryScreen())));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'AHMED SALEH');
      await tester.pump();
      expect((made.bloc.state as ServiceBookingInProgress).travelers.first.fieldValues['fullName'], 'AHMED SALEH');

      made.bloc.add(TravelerFieldChanged(travelerIndex: 0, fieldKey: 'birthDate', value: DateTime(1990, 5, 1)));
      await tester.pumpAndSettle();
      expect(find.text('1990 / 05 / 01'), findsOneWidget);
    });

    testWidgets('valid travelers go to review; submit stays off until confirmed, then reaches success', (tester) async {
      final repo = await pumpTravelers(tester);
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
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single.serviceId, 's1');
      expect(find.text(lookupAppLocalizations(const Locale('ar')).bookingSuccessTitle), findsOneWidget);
    });
  });
}
