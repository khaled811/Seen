// Requests search (Figma REQ-13) and the per-traveler documents sheet
// (Figma REQ-12). Arabic / RTL.

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
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/data/datasources/in_memory_recent_searches_store.dart';
import 'package:seen_booking/features/requests/data/models/request_summary_dto.dart';
import 'package:seen_booking/features/requests/data/models/request_traveler_status_dto.dart';
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/requests_page.dart';
import 'package:seen_booking/features/requests/domain/entities/request_traveler_status.dart';
import 'package:seen_booking/features/requests/domain/repositories/recent_searches_store.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/requests/domain/usecases/cancel_request_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/remind_approver_usecase.dart';
import 'package:seen_booking/features/requests/presentation/bloc/approver_reminder_cubit.dart';
import 'package:seen_booking/features/requests/presentation/bloc/recent_searches_cubit.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_bloc.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_event.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_state.dart';
import 'package:seen_booking/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:seen_booking/features/requests/presentation/screens/requests_search_screen.dart';
import '../../../support/requests_fakes.dart';

RequestSummary _summary(String id, String ref, RequestStatus status, List<String> names,
        {String service = 'حجز طيران'}) =>
    RequestSummary(
      id: id,
      referenceId: ref,
      serviceName: service,
      travelerCount: names.length,
      totalPriceCents: 10000,
      status: status,
      submittedAt: DateTime(2026, 10, 1),
      travelerNames: names,
    );

final _summaries = [
  _summary('1', 'SB-20488', RequestStatus.submitted, ['محمد عبدالله الحميري']),
  _summary('2', 'SB-20487', RequestStatus.infoRequired, ['رقية أحمد الحميري', 'منى علي']),
  _summary('3', 'SB-20481', RequestStatus.submitted, ['سالم محمد الحميري']),
  _summary('4', 'SB-20476', RequestStatus.completed, ['سارة باوزير'], service: 'دخول مصر'),
];

RequestDetail _detailWithDocs() => RequestDetail(
      id: 'r1',
      referenceId: 'SB-20481',
      serviceName: 'حجز طيران',
      status: RequestStatus.completed,
      totalPriceCents: 10000,
      submittedAt: DateTime(2026, 10, 1),
      travelers: const [
        RequestTravelerStatus(
          name: 'محمد',
          status: TravelerApprovalStatus.approved,
          documents: [
            TravelerDocument(name: 'الموافقة الأمنية.pdf', url: 'u1', status: TravelerDocumentStatus.issued),
            TravelerDocument(name: 'صورة الجواز.jpg', url: 'u2', status: TravelerDocumentStatus.approved),
          ],
        ),
        RequestTravelerStatus(
          name: 'رقية',
          status: TravelerApprovalStatus.approved,
          documents: [
            TravelerDocument(name: 'صورة الجواز.jpg', url: 'u3', status: TravelerDocumentStatus.inReview),
          ],
        ),
        RequestTravelerStatus(name: 'سالم', status: TravelerApprovalStatus.approved),
      ],
      timeline: const [],
    );

class _Repo implements RequestsRepository {
  _Repo({this.detail});
  final RequestDetail? detail;

  @override
  Future<Either<Failure, RequestsPage>> getRequests({String group = 'all', String? search, int offset = 0, int limit = 30}) async =>
      Right(fakeRequestsPage(_summaries, group: group, search: search, offset: offset, limit: limit));

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async =>
      detail == null ? const Left(ServerFailure('x')) : Right(detail!);

  @override
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId, {CancelReason? reason}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async => const Right(null);
}

class _MemoryRecents implements RecentSearchesStore {
  _MemoryRecents([List<String> initial = const []]) : _items = [...initial];
  List<String> _items;

  @override
  Future<List<String>> read() async => _items;

  @override
  Future<List<String>> remember(String query) async {
    _items = [query, ..._items.where((q) => q != query)].take(RecentSearchesStore.maxItems).toList();
    return _items;
  }

  @override
  Future<void> clear() async => _items = [];
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

RequestsBloc _bloc(_Repo repo) => RequestsBloc(
      getRequestsUseCase: GetRequestsUseCase(repo),
      getRequestDetailUseCase: GetRequestDetailUseCase(repo),
      cancelRequestUseCase: CancelRequestUseCase(repo),
    );

void main() {
  final storage = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        switch (call.method) {
          case 'read':
            return storage[args['key']];
          case 'write':
            storage[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
            storage.remove(args['key']);
            return null;
        }
        return null;
      },
    );
    InjectionContainer.instance.init();
  });

  group('wire mapping and search model', () {
    test('summary and traveler documents map from JSON', () {
      final summary = RequestSummaryDto.fromJson(const {
        'id': '1',
        'referenceId': 'SB-1',
        'serviceName': 'x',
        'travelerCount': 2,
        'totalPriceAmount': '10.00',
        'status': 'submitted',
        'submittedAt': '2026-10-01T00:00:00Z',
        'travelerNames': ['أ', 'ب'],
      }).toEntity();
      expect(summary.travelerNames, ['أ', 'ب']);
      final traveler = RequestTravelerStatusDto.fromJson(const {
        'name': 'أ',
        'documents': [
          {'name': 'd.pdf', 'url': 'u', 'status': 'ISSUED'},
          {'name': 'e.jpg', 'status': 'IN_REVIEW'},
          {'name': 'f.jpg', 'status': 'WHATEVER'},
        ],
      }).toEntity();
      expect(traveler.documents.map((d) => d.status), [
        TravelerDocumentStatus.issued,
        TravelerDocumentStatus.inReview,
        TravelerDocumentStatus.unknown,
      ]);
      expect(_detailWithDocs().hasTravelerDocuments, true);
    });

    test('the in-memory recents store keeps the newest five, without duplicates, and clears', () async {
      final store = InMemoryRecentSearchesStore();
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f']) {
        await store.remember(q);
      }
      expect(await store.read(), ['f', 'e', 'd', 'c', 'b']);
      expect(await store.remember('D'), ['D', 'f', 'e', 'c', 'b']);
      expect(await store.remember('  '), ['D', 'f', 'e', 'c', 'b']);
      await store.clear();
      expect(await store.read(), isEmpty);
    });

    test('recent searches are never written to secure storage', () async {
      storage.clear();
      final store = InMemoryRecentSearchesStore();
      await store.remember('AHMED SALEH');
      expect(storage, isEmpty);
    });
  });

  group('RequestsSearchScreen', () {
    Future<RequestsBloc> open(WidgetTester tester, {List<String> recents = const []}) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = _bloc(_Repo())..add(const RequestsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await settle(tester);
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(RequestsSearchScreen(createRecents: () => RecentSearchesCubit(_MemoryRecents(recents)))),
      ));
      await settle(tester);
      return bloc;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
    }

    testWidgets('typing lists the matching requests with the count', (tester) async {
      await open(tester);
      await type(tester, 'الحميري');
      expect(find.text('٣ نتائج لـ «الحميري»'), findsOneWidget);
      expect(find.text('محمد عبدالله الحميري'), findsOneWidget);
      expect(find.text('رقية أحمد الحميري'), findsOneWidget);
      expect(find.text('سالم محمد الحميري'), findsOneWidget);
      expect(find.text('SB-20488'), findsOneWidget);
      expect(find.text('سارة باوزير'), findsNothing);
    });

    testWidgets('a query with no match shows the empty card', (tester) async {
      await open(tester);
      await type(tester, 'SB-1999');
      expect(find.text('لا نتائج لـ «SB-1999»'), findsOneWidget);
      expect(find.text('جرّب رقم الطلب كاملًا أو اسم المسافر'), findsOneWidget);
    });

    testWidgets('recent searches show as chips, fill the field, and can be cleared', (tester) async {
      await open(tester, recents: ['سارة باوزير', 'SB-20476']);
      expect(find.text('عمليات بحث سابقة'), findsOneWidget);
      await tester.tap(find.text('سارة باوزير'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(find.text('نتيجة واحدة لـ «سارة باوزير»'), findsOneWidget);
      await tester.tap(find.text('مسح'));
      await settle(tester);
      expect(find.text('عمليات بحث سابقة'), findsNothing);
    });

    testWidgets('leaving the search clears the dashboard query', (tester) async {
      final bloc = await open(tester);
      await type(tester, 'الحميري');
      expect((bloc.state as RequestsLoaded).searchQuery, 'الحميري');
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect((bloc.state as RequestsLoaded).searchQuery, '');
    });
  });

  group('traveler documents sheet', () {
    testWidgets('View documents lists each traveler with document statuses', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repo(detail: _detailWithDocs());
      final bloc = _bloc(repo)..add(const RequestsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await settle(tester);
      bloc.add(const RequestDetailRequested('r1'));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(RequestDetailScreen(
          createReminderCubit: () => ApproverReminderCubit(remindApprover: RemindApproverUseCase(repo)),
        )),
      ));
      await settle(tester);
      // The ticket's meta row overflows in the test's Ahem font only.
      tester.takeException();
      await tester.tap(find.text('عرض المستندات'));
      await settle(tester);
      expect(find.text('مستندات الطلب'), findsOneWidget);
      expect(find.text('الموافقة الأمنية.pdf'), findsOneWidget);
      expect(find.text('صادرة'), findsOneWidget);
      expect(find.text('معتمدة'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('صورة الجواز.jpg'), findsNWidgets(2));
      expect(find.text('لا توجد مستندات لهذا المسافر بعد.'), findsOneWidget);
    });
  });
}
