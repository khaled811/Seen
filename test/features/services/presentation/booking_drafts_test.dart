// Booking drafts (Figma REQ-01 … 04): storage rules, serialization, the missing-
// data summary, the drafts bloc and screen, resuming into the booking bloc and
// the leave-form prompt. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/data/datasources/booking_draft_local_data_source.dart';
import 'package:seen_booking/features/services/data/repositories/booking_draft_repository_impl.dart';
import 'package:seen_booking/features/services/domain/entities/booking_draft.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_request.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/entities/traveler_info.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_draft_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/domain/usecases/submit_booking_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/drafts_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/services/presentation/screens/drafts_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';
import 'package:seen_booking/features/services/presentation/utils/draft_summary.dart';
import 'package:seen_booking/features/services/presentation/widgets/service_traveler_fields.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

final _now = DateTime(2026, 10, 17, 12);
final _l10n = lookupAppLocalizations(const Locale('ar'));

const _service = ServiceDefinition(
  id: 's1',
  category: ServiceCategory.egyptNationalSecurity,
  name: 'موافقة الأمن الوطني',
  description: 'موافقة دخول مصر',
  perPersonPriceCents: 8500,
  availability: ServiceAvailability.available,
);

final _fields = ServiceTravelerFields.forCategory(
    ServiceCategory.egyptNationalSecurity, _l10n);

Map<String, Object?> _complete() => {
      'fullName': 'AHMED SALEH',
      'passportNumber': 'A1234567',
      'nationality': 'يمني',
      'birthDate': DateTime(1990, 5, 1),
      'passportIssueDate': DateTime(2020, 5, 1),
      'passportExpiryDate': DateTime(2035, 5, 1),
    };

BookingDraft _draft(
  String id, {
  DateTime? updatedAt,
  List<TravelerInfo>? travelers,
}) =>
    BookingDraft(
      id: id,
      serviceId: 's1',
      serviceName: 'موافقة الأمن الوطني',
      category: ServiceCategory.egyptNationalSecurity,
      travelers: travelers ?? [TravelerInfo(id: 't', fieldValues: _complete())],
      updatedAt: updatedAt ?? _now.subtract(const Duration(hours: 2)),
    );

class _MemoryLocal implements BookingDraftLocalDataSource {
  List<BookingDraft> items = [];

  @override
  Future<List<BookingDraft>> read() async => List.of(items);

  @override
  Future<void> write(List<BookingDraft> drafts) async =>
      items = List.of(drafts);
}

class _Services implements ServicesRepository {
  final submitted = <ServiceBookingRequest>[];

  @override
  Future<Either<Failure, List<ServiceDefinition>>>
      getAvailableServices() async => const Right([_service]);

  @override
  Future<Either<Failure, ServiceBookingResult>> submitBooking(
      ServiceBookingRequest request) async {
    submitted.add(request);
    return Right(ServiceBookingResult(
      requestId: 'SB-1',
      status: RequestStatus.submitted,
      totalPriceCents: 8500,
      createdAt: _now,
    ));
  }
}

class _Wallet implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(
            availableCents: 100000,
            holdCents: 0,
            creditLimitCents: 0,
            currency: WalletCurrency.usd),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

({BookingDraftRepositoryImpl repo, _MemoryLocal local}) _repo() {
  final local = _MemoryLocal();
  return (
    repo: BookingDraftRepositoryImpl(local: local, clock: () => _now),
    local: local
  );
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

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('BookingDraft', () {
    test('expires 30 days after the last edit and counts the days left', () {
      final d = _draft('a', updatedAt: _now.subtract(const Duration(days: 28)));
      expect(d.isExpired(_now), false);
      expect(d.daysLeft(_now), 2);
      expect(
          _draft('b', updatedAt: _now.subtract(const Duration(days: 31)))
              .isExpired(_now),
          true);
    });
  });

  group('BookingDraftJson', () {
    test('keeps strings and dates through a round trip', () {
      final d = _draft('a');
      final back = BookingDraftJson.fromJson(BookingDraftJson.toJson(d));
      expect(
          back.travelers.single.fieldValues['birthDate'], DateTime(1990, 5, 1));
      expect(back.travelers.single.fieldValues['fullName'], 'AHMED SALEH');
      expect(back.category, ServiceCategory.egyptNationalSecurity);
      expect(back.updatedAt, d.updatedAt);
    });
  });

  group('BookingDraftRepositoryImpl', () {
    test('lists newest edit first and removes expired drafts for good',
        () async {
      final r = _repo();
      r.local.items = [
        _draft('old', updatedAt: _now.subtract(const Duration(days: 40))),
        _draft('a', updatedAt: _now.subtract(const Duration(days: 3))),
        _draft('b', updatedAt: _now.subtract(const Duration(hours: 1))),
      ];
      final list = (await r.repo.getDrafts()).getOrElse((_) => []);
      expect(list.map((d) => d.id), ['b', 'a']);
      expect(r.local.items.map((d) => d.id), ['a', 'b']);
    });

    test('refuses an 11th new draft but still overwrites an existing one',
        () async {
      final r = _repo();
      r.local.items = [
        for (var i = 0; i < BookingDraft.maxCount; i++) _draft('d$i')
      ];
      expect(await r.repo.saveDraft(_draft('new')),
          const Right<Failure, SaveDraftResult>(SaveDraftResult.limitReached));
      expect(r.local.items.length, BookingDraft.maxCount);
      expect(await r.repo.saveDraft(_draft('d3')),
          const Right<Failure, SaveDraftResult>(SaveDraftResult.saved));
      expect(r.local.items.length, BookingDraft.maxCount);
    });

    test('delete removes only that draft', () async {
      final r = _repo();
      r.local.items = [_draft('a'), _draft('b')];
      await r.repo.deleteDraft('a');
      expect(r.local.items.map((d) => d.id), ['b']);
    });
  });

  group('draft summary', () {
    final s = SeenStrings.forLocale(const Locale('ar'));

    test('a complete draft has no missing line', () {
      expect(draftMissingLine(_draft('a'), _l10n, s), isNull);
    });

    test('one traveler missing one field names the field', () {
      final values = _complete()..remove('passportExpiryDate');
      final line = draftMissingLine(
          _draft('a', travelers: [TravelerInfo(id: 't', fieldValues: values)]),
          _l10n,
          s);
      final label =
          _fields.firstWhere((f) => f.key == 'passportExpiryDate').label;
      expect(line, 'ينقص: $label');
    });

    test(
        'several incomplete travelers are counted; one with many gaps is named by traveler',
        () {
      final many = BookingDraft(
        id: 'a',
        serviceId: 's1',
        serviceName: 'x',
        category: ServiceCategory.egyptNationalSecurity,
        updatedAt: _now,
        travelers: [
          const TravelerInfo(id: '1', fieldValues: {}),
          TravelerInfo(id: '2', fieldValues: _complete()),
          const TravelerInfo(id: '3', fieldValues: {}),
        ],
      );
      expect(draftMissingLine(many, _l10n, s), 'ينقص: بيانات ٢ مسافرين');
      final one = many
          .copyWith(travelers: [const TravelerInfo(id: '1', fieldValues: {})]);
      expect(draftMissingLine(one, _l10n, s), 'ينقص: بيانات المسافر ١');
    });

    test('dirty means at least one non-blank value', () {
      expect(
          hasAnyTravelerData([
            const TravelerInfo(id: '1', fieldValues: {'fullName': '  '})
          ]),
          false);
      expect(
          hasAnyTravelerData([
            const TravelerInfo(id: '1', fieldValues: {'fullName': 'A'})
          ]),
          true);
    });
  });

  group('SeenStrings', () {
    final s = SeenStrings.forLocale(const Locale('ar'));

    test('draft count forms and age wording', () {
      expect(s.draftCount(1), 'مسودة واحدة');
      expect(s.draftCount(2), 'مسودتان');
      expect(s.draftCount(3), '٣ مسودات');
      expect(s.draftAge(_now.subtract(const Duration(days: 3)), now: _now),
          'قبل ٣ أيام');
      expect(
          s.draftAge(_now.subtract(const Duration(days: 1)), now: _now), 'أمس');
      expect(s.draftDeletesIn(2), 'تُحذف خلال يومين');
      expect(s.draftDeletesIn(1), 'تُحذف غدًا');
    });
  });

  group('DraftsBloc', () {
    DraftsBloc make(_MemoryLocal local) {
      final repo = BookingDraftRepositoryImpl(local: local, clock: () => _now);
      return DraftsBloc(
        getDrafts: GetBookingDraftsUseCase(repo),
        deleteDraft: DeleteBookingDraftUseCase(repo),
        saveDraft: SaveBookingDraftUseCase(repo),
      );
    }

    test('delete then undo restores the same draft', () async {
      final local = _MemoryLocal()
        ..items = [
          _draft('a'),
          _draft('b', updatedAt: _now.subtract(const Duration(days: 1)))
        ];
      final bloc = make(local);
      addTearDown(bloc.close);
      bloc.add(const DraftsLoadRequested());
      await bloc.stream.firstWhere((s) => s.status == DraftsStatus.ready);

      bloc.add(DraftDeleteRequested(bloc.state.drafts.first));
      var s = await bloc.stream.firstWhere((s) => s.lastDeleted != null);
      expect(s.drafts.map((d) => d.id), ['b']);
      expect(local.items.map((d) => d.id), ['b']);

      bloc.add(const DraftDeleteUndone());
      s = await bloc.stream.firstWhere((s) => s.lastDeleted == null);
      expect(s.drafts.map((d) => d.id), ['a', 'b']);
    });
  });

  group('DraftsScreen', () {
    late _MemoryLocal local;

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = BookingDraftRepositoryImpl(local: local, clock: () => _now);
      await tester.pumpWidget(_app(DraftsScreen(
        clock: () => _now,
        createBloc: () => DraftsBloc(
          getDrafts: GetBookingDraftsUseCase(repo),
          deleteDraft: DeleteBookingDraftUseCase(repo),
          saveDraft: SaveBookingDraftUseCase(repo),
        ),
      )));
      await settle(tester);
    }

    setUp(() => local = _MemoryLocal());

    testWidgets('empty: the empty state', (tester) async {
      await open(tester);
      expect(find.text('لا توجد مسودات'), findsOneWidget);
    });

    testWidgets(
        'cards show the chip, travelers, what is missing, age and the near-deletion warning',
        (tester) async {
      local.items = [
        _draft('a'),
        _draft('b',
            updatedAt: _now.subtract(const Duration(days: 28)),
            travelers: [
              const TravelerInfo(id: '1', fieldValues: {}),
              TravelerInfo(id: '2', fieldValues: _complete())
            ]),
      ];
      await open(tester);
      expect(find.text('٢ مسودات'), findsNothing);
      expect(find.text('مسودتان'), findsOneWidget);
      expect(find.text('مسودة'), findsNWidgets(2));
      expect(find.text('قبل ساعتين'), findsOneWidget);
      expect(find.text('ينقص: بيانات المسافر ١'), findsOneWidget);
      expect(find.text('تُحذف خلال يومين'), findsOneWidget);
      expect(find.textContaining('٣٠ يومًا'), findsOneWidget);
    });

    testWidgets('delete asks first, mentions the last draft, then offers undo',
        (tester) async {
      local.items = [_draft('a')];
      await open(tester);
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(find.text('حذف المسودة؟'), findsOneWidget);
      expect(find.textContaining('هذه آخر مسودة لديك'), findsOneWidget);

      await tester.tap(
          find.descendant(of: find.byType(Dialog), matching: find.text('حذف')));
      await settle(tester);
      expect(local.items, isEmpty);
      expect(find.text('حُذفت المسودة'), findsOneWidget);
      expect(find.text('لا توجد مسودات'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect(local.items.map((d) => d.id), ['a']);
      expect(find.text('موافقة الأمن الوطني'), findsOneWidget);
    });

    testWidgets('cancel keeps the draft', (tester) async {
      local.items = [_draft('a'), _draft('b')];
      await open(tester);
      await tester.tap(find.text('حذف').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('هذه آخر مسودة'), findsNothing);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(local.items.length, 2);
    });
  });

  group('resuming and sending', () {
    ({ServiceBookingBloc bloc, _MemoryLocal local}) make() {
      final local = _MemoryLocal();
      final repo = BookingDraftRepositoryImpl(local: local, clock: () => _now);
      final services = _Services();
      final bloc = ServiceBookingBloc(
        getAvailableServicesUseCase: GetAvailableServicesUseCase(services),
        submitBookingUseCase: SubmitBookingUseCase(services),
        getWalletBalanceUseCase: GetWalletBalanceUseCase(_Wallet()),
        validator: ServiceSelectionScreen.buildValidator(_l10n),
        deleteDraftUseCase: DeleteBookingDraftUseCase(repo),
      );
      return (bloc: bloc, local: local);
    }

    test('a resumed draft opens with its travelers and remembers its id',
        () async {
      final m = make();
      addTearDown(m.bloc.close);
      m.bloc.add(BookingDraftResumed(
          service: _service, travelerFields: _fields, draft: _draft('a')));
      final s =
          await m.bloc.stream.firstWhere((s) => s is ServiceBookingInProgress)
              as ServiceBookingInProgress;
      expect(s.draftId, 'a');
      expect(s.travelers.single.fieldValues['fullName'], 'AHMED SALEH');
    });

    test('sending a resumed booking deletes its draft', () async {
      final m = make();
      addTearDown(m.bloc.close);
      m.local.items = [_draft('a'), _draft('keep')];
      m.bloc.add(BookingDraftResumed(
          service: _service, travelerFields: _fields, draft: _draft('a')));
      await m.bloc.stream.firstWhere(
          (s) => s is ServiceBookingInProgress && !s.walletBalanceLoading);
      m.bloc.add(const BookingSubmitted());
      await m.bloc.stream.firstWhere(
        (s) =>
            s is ServiceBookingInProgress &&
            s.submissionStatus == BookingSubmissionStatus.success,
      );
      expect(m.local.items.map((d) => d.id), ['keep']);
    });
  });

  group('leave-form prompt (REQ-04)', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
      InjectionContainer.instance.init();
    });

    Future<ServiceBookingBloc> open(WidgetTester tester,
        {required bool withData}) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final services = _Services();
      final bloc = ServiceBookingBloc(
        getAvailableServicesUseCase: GetAvailableServicesUseCase(services),
        submitBookingUseCase: SubmitBookingUseCase(services),
        getWalletBalanceUseCase: GetWalletBalanceUseCase(_Wallet()),
        validator: ServiceSelectionScreen.buildValidator(_l10n),
      );
      addTearDown(() => bloc.close().ignore());
      bloc.add(ServiceSelected(service: _service, travelerFields: _fields));
      await settle(tester);
      if (withData) {
        bloc.add(const TravelerFieldChanged(
            travelerIndex: 0, fieldKey: 'fullName', value: 'AHMED SALEH'));
      }
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                  value: bloc, child: const TravelerEntryScreen()),
            )),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('with nothing entered, back leaves without asking',
        (tester) async {
      await open(tester, withData: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.text('حفظ الطلب كمسودة؟'), findsNothing);
    });

    testWidgets(
        'with data, back asks; dismiss stays; discard leaves; save stores and leaves',
        (tester) async {
      await open(tester, withData: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('حفظ الطلب كمسودة؟'), findsOneWidget);
      expect(find.text('بيانات المسافر ١ · ناقصة'), findsOneWidget);

      // Dismiss (tap the scrim): stay on the form.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsNothing);

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('حفظ كمسودة'));
      await settle(tester);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('حُفظت المسودة.'), findsOneWidget);
    });

    testWidgets('discard and leave goes back without saving', (tester) async {
      await open(tester, withData: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('تجاهل والخروج'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.text('حُفظت المسودة.'), findsNothing);
    });
  });
}
