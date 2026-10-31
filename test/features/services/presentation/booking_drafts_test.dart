// Booking drafts (Figma REQ-01 … 04): the server's drafts list, deleting a draft
// (the server cancels it), and the leave-form prompt that files the draft on the
// server. Nothing is stored on the device. Arabic / RTL.

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
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/requests_page.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/drafts_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/screens/drafts_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/traveler_entry_screen.dart';
import 'package:seen_booking/features/services/presentation/utils/draft_summary.dart';
import 'package:seen_booking/features/services/domain/entities/traveler_info.dart';

import '../../../support/booking_fakes.dart';

final _now = DateTime(2026, 10, 17, 12);
final _l10n = lookupAppLocalizations(const Locale('ar'));

RequestSummary _draft(String id, {int travelers = 1, Duration age = const Duration(hours: 2)}) => RequestSummary(
      id: id,
      referenceId: '',
      serviceName: 'موافقة الأمن الوطني',
      travelerCount: travelers,
      totalPriceCents: 8500,
      status: RequestStatus.draft,
      submittedAt: _now.subtract(age),
    );

class _Services implements ServicesRepository {
  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async => const Right([bookingTestService]);
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
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

DraftsBloc _draftsBloc(FakeBookingRequestsRepository repo, {int pageSize = 30}) => DraftsBloc(
      getRequests: GetRequestsUseCase(repo),
      pageSize: pageSize,
    );

void main() {
  group('draft summary', () {
    test('dirty means at least one non-blank value', () {
      expect(hasAnyTravelerData([const TravelerInfo(id: '1', fieldValues: {'fullName': '  '})]), false);
      expect(hasAnyTravelerData([const TravelerInfo(id: '1', fieldValues: {'fullName': 'A'})]), true);
    });

    test('a field shown by a condition counts as missing only while it shows', () {
      const traveler = TravelerInfo(id: '1', fieldValues: {'fullName': 'A', 'birthDate': null, 'status': 'single'});
      final single = travelerCompleteness([traveler], bookingTestService.fields).single;
      expect(single.missingLabels, ['Birth date']);
      const married = TravelerInfo(id: '1', fieldValues: {'fullName': 'A', 'birthDate': null, 'status': 'married'});
      expect(travelerCompleteness([married], bookingTestService.fields).single.missingLabels, ['Birth date', 'Spouse']);
    });
  });

  group('SeenStrings', () {
    final s = SeenStrings.forLocale(const Locale('ar'));

    test('draft count forms and age wording', () {
      expect(s.draftCount(1), 'مسودة واحدة');
      expect(s.draftCount(2), 'مسودتان');
      expect(s.draftCount(3), '٣ مسودات');
      expect(s.draftAge(_now.subtract(const Duration(days: 3)), now: _now), 'قبل ٣ أيام');
      expect(s.draftAge(_now.subtract(const Duration(days: 1)), now: _now), 'أمس');
    });
  });

  group('DraftsBloc', () {
    late FakeBookingRequestsRepository repo;

    setUp(() => repo = FakeBookingRequestsRepository());

    test('loads the server drafts (group draft), nothing from the device', () async {
      repo.page = RequestsPage(items: [_draft('a'), _draft('b')], total: 2, hasMore: false);
      final bloc = _draftsBloc(repo)..add(const DraftsLoadRequested());
      await pumpEventQueue();
      expect(bloc.state.status, DraftsStatus.ready);
      expect(bloc.state.drafts.map((d) => d.id), ['a', 'b']);
      expect(repo.pages.single.group, 'draft');
      await bloc.close();
    });

    test('a load that fails is a failed state with the failure', () async {
      repo.pageResult = const Left(NetworkFailure('off'));
      final bloc = _draftsBloc(repo)..add(const DraftsLoadRequested());
      await pumpEventQueue();
      expect(bloc.state.status, DraftsStatus.failed);
      expect(bloc.state.failure, isA<NetworkFailure>());
      await bloc.close();
    });

    test('pages: the next page is appended once, with no duplicates, then stops', () async {
      final all = [for (var i = 0; i < 5; i++) _draft('d$i')];
      // A repo that really pages.
      final paging = _PagingRepo(all);
      final bloc = DraftsBloc(
        getRequests: GetRequestsUseCase(paging),
        pageSize: 2,
      )..add(const DraftsLoadRequested());
      await pumpEventQueue();
      expect(bloc.state.drafts, hasLength(2));
      expect(bloc.state.hasMore, isTrue);
      bloc.add(const DraftsLoadMoreRequested());
      await pumpEventQueue();
      expect(bloc.state.drafts.map((d) => d.id), ['d0', 'd1', 'd2', 'd3']);
      expect(paging.calls, [0, 2]);
      bloc.add(const DraftsLoadMoreRequested());
      await pumpEventQueue();
      expect(bloc.state.drafts, hasLength(5));
      expect(bloc.state.hasMore, isFalse);
      bloc.add(const DraftsLoadMoreRequested());
      await pumpEventQueue();
      expect(paging.calls, hasLength(3));
      await bloc.close();
    });
  });

  group('DraftsScreen', () {
    late FakeBookingRequestsRepository repo;

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(DraftsScreen(clock: () => _now, createBloc: () => _draftsBloc(repo))));
      await settle(tester);
    }

    setUp(() => repo = FakeBookingRequestsRepository());

    testWidgets('empty: the empty state', (tester) async {
      await open(tester);
      expect(find.text('لا توجد مسودات'), findsOneWidget);
    });

    testWidgets('a failed load shows the retry, which loads again', (tester) async {
      repo.pageResult = const Left(NetworkFailure('off'));
      await open(tester);
      expect(find.text(_l10n.errorSectionLoad), findsOneWidget);
      repo.pageResult = null;
      repo.page = RequestsPage(items: [_draft('a')], total: 1, hasMore: false);
      await tester.tap(find.text(_l10n.retry));
      await settle(tester);
      expect(find.text('موافقة الأمن الوطني'), findsOneWidget);
    });

    testWidgets('cards show the chip, traveler count and age; no invented expiry or missing line', (tester) async {
      repo.page = RequestsPage(items: [_draft('a'), _draft('b', travelers: 3, age: const Duration(days: 28))], total: 2, hasMore: false);
      await open(tester);
      expect(find.text('مسودتان'), findsOneWidget);
      expect(find.text('مسودة'), findsNWidgets(2));
      expect(find.text('قبل ساعتين'), findsOneWidget);
      expect(find.textContaining('تُحذف'), findsNothing);
      expect(find.textContaining('ينقص'), findsNothing);
      expect(find.textContaining('٣٠ يومًا'), findsNothing);
    });

    testWidgets('a draft can be continued but not deleted: the API cannot cancel a draft', (tester) async {
      repo.page = RequestsPage(items: [_draft('a')], total: 1, hasMore: false);
      await open(tester);
      expect(find.text('متابعة'), findsOneWidget);
      expect(find.text('حذف'), findsNothing);
      expect(repo.cancelled, isEmpty);
    });
  });

  group('leave-form prompt (REQ-04)', () {
    late FakeBookingFlowRepository flow;
    late FakeBookingRequestsRepository requests;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
      InjectionContainer.instance.init();
      flow = FakeBookingFlowRepository();
      requests = FakeBookingRequestsRepository();
    });

    Future<ServiceBookingBloc> open(WidgetTester tester, {bool name = false, bool complete = false}) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = ServiceBookingBloc(
        getAvailableServicesUseCase: GetAvailableServicesUseCase(_Services()),
        createDraftUseCase: CreateDraftRequestUseCase(flow),
        addTravelersUseCase: AddTravelersUseCase(flow),
        uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
        reviewDraftUseCase: ReviewDraftUseCase(flow),
        submitDraftUseCase: SubmitDraftRequestUseCase(flow),
        getRequestDetailUseCase: GetRequestDetailUseCase(requests),
        validator: ServiceSelectionScreen.buildValidator(_l10n),
      );
      addTearDown(() => bloc.close().ignore());
      bloc.add(const ServiceSelected(service: bookingTestService));
      await settle(tester);
      if (name || complete) {
        bloc.add(const TravelerFieldChanged(travelerIndex: 0, fieldKey: 'fullName', value: 'AHMED SALEH'));
      }
      if (complete) {
        bloc.add(TravelerFieldChanged(travelerIndex: 0, fieldKey: 'birthDate', value: DateTime(1990, 5, 1)));
      }
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(value: bloc, child: const TravelerEntryScreen()),
            )),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('with nothing entered, back leaves without asking', (tester) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.text('حفظ الطلب كمسودة؟'), findsNothing);
    });

    testWidgets('with incomplete data the sheet cannot save: it says why and only discard is possible', (tester) async {
      await open(tester, name: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('حفظ الطلب كمسودة؟'), findsOneWidget);
      expect(find.text(_l10n.draftSaveRowMissing('١')), findsOneWidget);
      expect(find.text(_l10n.draftSaveNeedsComplete), findsOneWidget);
      final save = tester.widget<SeenButton>(find.widgetWithText(SeenButton, 'حفظ كمسودة'));
      expect(save.onPressed, isNull);
      expect(flow.created, isEmpty);

      // Dismiss (tap the scrim): stay on the form.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsNothing);
    });

    testWidgets('with complete data, save files the draft on the server and leaves', (tester) async {
      await open(tester, complete: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(_l10n.draftSaveNeedsComplete), findsNothing);
      await tester.tap(find.text('حفظ كمسودة'));
      await settle(tester);
      expect(flow.created, ['svc-1']);
      expect(flow.added, hasLength(1));
      expect(flow.reviewed, isEmpty);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('حُفظت المسودة.'), findsOneWidget);
    });

    testWidgets('a save the server cannot take keeps the form and says why', (tester) async {
      flow.createResult = const Left(NetworkFailure('off'));
      await open(tester, complete: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('حفظ كمسودة'));
      await settle(tester);
      expect(find.text('open'), findsNothing);
      expect(find.text(_l10n.errorNetwork), findsOneWidget);
    });

    testWidgets('discard and leave goes back without saving', (tester) async {
      await open(tester, name: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('تجاهل والخروج'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(flow.created, isEmpty);
    });
  });
}

/// A requests repository that really pages a fixed list.
class _PagingRepo extends FakeBookingRequestsRepository {
  _PagingRepo(this.all);

  final List<RequestSummary> all;
  final calls = <int>[];

  @override
  Future<Either<Failure, RequestsPage>> getRequests({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  }) async {
    calls.add(offset);
    final items = all.skip(offset).take(limit).toList();
    return Right(RequestsPage(items: items, total: all.length, hasMore: offset + items.length < all.length));
  }
}
