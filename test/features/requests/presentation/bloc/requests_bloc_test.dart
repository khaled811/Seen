import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/request_timeline_entry.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/requests/domain/usecases/cancel_request_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_bloc.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_event.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_state.dart';

RequestSummary _summary(String id, RequestStatus status) => RequestSummary(
      id: id,
      referenceId: 'SB-$id',
      serviceName: 'Egypt National Security Approval',
      travelerCount: 1,
      totalPriceCents: 15000,
      status: status,
      submittedAt: DateTime(2026, 1, 1),
    );

final _requests = [
  _summary('1', RequestStatus.draft),
  _summary('2', RequestStatus.submitted),
  _summary('3', RequestStatus.underReview),
  _summary('4', RequestStatus.infoRequired),
  _summary('5', RequestStatus.completed),
  _summary('6', RequestStatus.rejected),
  _summary('7', RequestStatus.cancelled),
];

RequestDetail _detailFor(String id, RequestStatus status) => RequestDetail(
      id: id,
      referenceId: 'SB-$id',
      serviceName: 'Egypt National Security Approval',
      status: status,
      totalPriceCents: 15000,
      submittedAt: DateTime(2026, 1, 1),
      travelers: const [],
      timeline: [
        RequestTimelineEntry(status: status, occurredAt: DateTime(2026, 1, 1)),
      ],
    );

class _FakeRequestsRepository implements RequestsRepository {
  Either<Failure, List<RequestSummary>> requestsResult = Right(_requests);
  Either<Failure, RequestDetail>? detailResult;
  Either<Failure, RequestDetail>? cancelResult;
  int detailCalls = 0;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, List<RequestSummary>>> getRequests() async => requestsResult;

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async {
    detailCalls++;
    return detailResult ??
        Right(
          _detailFor(
            requestId,
            _requests.firstWhere((r) => r.id == requestId).status,
          ),
        );
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async => const Right(null);

  @override
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId, {CancelReason? reason}) async {
    cancelCalls++;
    return cancelResult ?? Right(_detailFor(requestId, RequestStatus.cancelled));
  }
}

void main() {
  late _FakeRequestsRepository repository;
  late RequestsBloc bloc;

  setUp(() {
    repository = _FakeRequestsRepository();
    bloc = RequestsBloc(
      getRequestsUseCase: GetRequestsUseCase(repository),
      getRequestDetailUseCase: GetRequestDetailUseCase(repository),
      cancelRequestUseCase: CancelRequestUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  test('initial state is RequestsInitial', () {
    expect(bloc.state, const RequestsInitial());
  });

  test('RequestsLoadRequested emits [Loading, Loaded] with all 7 requests', () async {
    final states = <RequestsState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const RequestsLoadRequested());
    await bloc.stream.firstWhere((s) => s is RequestsLoaded);
    await sub.cancel();

    expect(states.first, const RequestsLoading());
    final loaded = states.last as RequestsLoaded;
    expect(loaded.requests, hasLength(7));
    expect(loaded.filter, RequestsDashboardFilter.all);
  });

  group('status filtering', () {
    Future<RequestsLoaded> load() async {
      bloc.add(const RequestsLoadRequested());
      return await bloc.stream.firstWhere((s) => s is RequestsLoaded) as RequestsLoaded;
    }

    test('all shows every request', () async {
      final state = await load();
      expect(state.filteredRequests, hasLength(7));
    });

    test('pendingUnderReview matches submitted/underReview/processing statuses', () async {
      await load();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.pendingUnderReview));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests.map((r) => r.id), ['2', '3']);
    });

    test('completed matches only RequestStatus.completed', () async {
      await load();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests.map((r) => r.id), ['5']);
    });

    test('actionRequired matches only RequestStatus.infoRequired', () async {
      await load();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.actionRequired));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests.map((r) => r.id), ['4']);
    });
  });

  group('search', () {
    Future<RequestsLoaded> load() async {
      bloc.add(const RequestsLoadRequested());
      return await bloc.stream.firstWhere((s) => s is RequestsLoaded) as RequestsLoaded;
    }

    test('matches by reference id, case-insensitively', () async {
      await load();
      bloc.add(const RequestsSearchChanged('sb-4'));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests.map((r) => r.id), ['4']);
    });

    test('no match returns an empty list rather than falling back to all', () async {
      await load();
      bloc.add(const RequestsSearchChanged('does-not-exist'));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests, isEmpty);
    });

    test('a burst of keystrokes is debounced to a single emission with the last query', () async {
      await load();
      final emitted = <RequestsLoaded>[];
      final sub = bloc.stream.listen((s) => emitted.add(s as RequestsLoaded));
      for (final q in ['s', 'sb', 'sb-', 'sb-4']) {
        bloc.add(RequestsSearchChanged(q));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(RequestsBloc.searchDebounce + const Duration(milliseconds: 100));
      await sub.cancel();

      expect(emitted, hasLength(1));
      expect(emitted.single.searchQuery, 'sb-4');
    });

    test('clearing the query restores the full filtered list', () async {
      await load();
      bloc.add(const RequestsSearchChanged('sb-4'));
      await bloc.stream.first;
      bloc.add(const RequestsSearchChanged(''));
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.filteredRequests, hasLength(7));
    });
  });

  group('ordering', () {
    test('action-required first, then SLA<24h ascending, then newest', () async {
      final now = DateTime.now();
      final ordered = [
        RequestSummary(
          id: 'old-completed',
          referenceId: 'SB-old',
          serviceName: 'x',
          travelerCount: 1,
          totalPriceCents: 100,
          status: RequestStatus.completed,
          submittedAt: now.subtract(const Duration(days: 5)),
        ),
        RequestSummary(
          id: 'urgent-2h',
          referenceId: 'SB-u2',
          serviceName: 'x',
          travelerCount: 1,
          totalPriceCents: 100,
          status: RequestStatus.underReview,
          submittedAt: now,
          slaDeadline: now.add(const Duration(hours: 2)),
        ),
        RequestSummary(
          id: 'new-completed',
          referenceId: 'SB-new',
          serviceName: 'x',
          travelerCount: 1,
          totalPriceCents: 100,
          status: RequestStatus.completed,
          submittedAt: now,
        ),
        RequestSummary(
          id: 'urgent-10h',
          referenceId: 'SB-u10',
          serviceName: 'x',
          travelerCount: 1,
          totalPriceCents: 100,
          status: RequestStatus.underReview,
          submittedAt: now,
          slaDeadline: now.add(const Duration(hours: 10)),
        ),
        RequestSummary(
          id: 'action',
          referenceId: 'SB-action',
          serviceName: 'x',
          travelerCount: 1,
          totalPriceCents: 100,
          status: RequestStatus.infoRequired,
          submittedAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      repository.requestsResult = Right(ordered);
      bloc.add(const RequestsLoadRequested());
      final state = await bloc.stream.firstWhere((s) => s is RequestsLoaded) as RequestsLoaded;

      expect(
        state.filteredRequests.map((r) => r.id),
        ['action', 'urgent-2h', 'urgent-10h', 'new-completed', 'old-completed'],
      );
    });
  });

  group('detail loading', () {
    test('RequestDetailRequested loads detail and sets detailReady', () async {
      bloc.add(const RequestsLoadRequested());
      await bloc.stream.firstWhere((s) => s is RequestsLoaded);

      bloc.add(const RequestDetailRequested('4'));
      await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailStatus == RequestDetailStatus.loading,
      );
      final loaded = await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailStatus == RequestDetailStatus.loaded,
      ) as RequestsLoaded;

      expect(loaded.detail!.id, '4');
      expect(loaded.detailReady, isTrue);
      expect(repository.detailCalls, 1);
    });

    test('RequestDetailAcknowledged clears the one-shot flag', () async {
      bloc.add(const RequestsLoadRequested());
      await bloc.stream.firstWhere((s) => s is RequestsLoaded);
      bloc.add(const RequestDetailRequested('4'));
      await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailReady,
      );

      bloc.add(const RequestDetailAcknowledged());
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.detailReady, isFalse);
      expect(state.detail!.id, '4'); // detail itself is preserved
    });

    test('surfaces a detail load failure', () async {
      bloc.add(const RequestsLoadRequested());
      await bloc.stream.firstWhere((s) => s is RequestsLoaded);

      repository.detailResult = const Left(ServerFailure('not found'));
      bloc.add(const RequestDetailRequested('4'));
      final failed = await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailStatus == RequestDetailStatus.failure,
      ) as RequestsLoaded;

      expect(failed.detailError, 'not found');
    });
  });

  group('cancellation', () {
    test('updates both the open detail and the dashboard row on success', () async {
      bloc.add(const RequestsLoadRequested());
      await bloc.stream.firstWhere((s) => s is RequestsLoaded);
      bloc.add(const RequestDetailRequested('4'));
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.detailReady);

      bloc.add(const RequestCancelSubmitted('4'));
      await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.cancelStatus == RequestCancelStatus.submitting,
      );
      final done = await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.cancelStatus == RequestCancelStatus.success,
      ) as RequestsLoaded;

      expect(done.detail!.status, RequestStatus.cancelled);
      expect(
        done.requests.firstWhere((r) => r.id == '4').status,
        RequestStatus.cancelled,
      );
    });
  });
}
