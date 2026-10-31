import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/request_timeline_entry.dart';
import 'package:seen_booking/features/requests/domain/entities/requests_page.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/requests/domain/usecases/cancel_request_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_bloc.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_event.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_state.dart';

import '../../../../support/requests_fakes.dart';

RequestSummary _summary(String id, RequestStatus status, {String? name}) => RequestSummary(
      id: id,
      referenceId: 'SB-$id',
      serviceName: 'Egypt National Security Approval',
      travelerCount: 1,
      totalPriceCents: 15000,
      status: status,
      submittedAt: DateTime(2026, 1, 1),
      travelerNames: [if (name != null) name],
    );

final _requests = [
  _summary('1', RequestStatus.draft),
  _summary('2', RequestStatus.submitted),
  _summary('3', RequestStatus.underReview),
  _summary('4', RequestStatus.infoRequired, name: 'Ahmed Saleh'),
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

class _Call {
  _Call(this.group, this.search, this.offset, this.limit);

  final String group;
  final String? search;
  final int offset;
  final int limit;
}

/// Plays the server: filters, searches and pages [all], like the real API.
class _FakeRequestsRepository implements RequestsRepository {
  List<RequestSummary> all = _requests;
  Failure? pageFailure;
  Either<Failure, RequestDetail>? detailResult;
  Either<Failure, RequestDetail?>? cancelResult;
  Completer<void>? gate;
  final pageCalls = <_Call>[];
  int detailCalls = 0;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, RequestsPage>> getRequests({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  }) async {
    pageCalls.add(_Call(group, search, offset, limit));
    await gate?.future;
    final failure = pageFailure;
    if (failure != null) return Left(failure);
    return Right(fakeRequestsPage(all, group: group, search: search, offset: offset, limit: limit));
  }

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async {
    detailCalls++;
    return detailResult ??
        Right(
          _detailFor(
            requestId,
            all.firstWhere((r) => r.id == requestId).status,
          ),
        );
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async => const Right(null);

  @override
  Future<Either<Failure, RequestDetail?>> cancelRequest(String requestId, {CancelReason? reason}) async {
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
      pageSize: 30,
    );
  });

  tearDown(() => bloc.close());

  Future<RequestsLoaded> load() async {
    bloc.add(const RequestsLoadRequested());
    return await bloc.stream.firstWhere((s) => s is RequestsLoaded) as RequestsLoaded;
  }

  test('initial state is RequestsInitial', () {
    expect(bloc.state, const RequestsInitial());
  });

  group('loading', () {
    test('emits [Loading, Loaded] with the first page, the server counts and the attention figures', () async {
      final states = <RequestsState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const RequestsLoadRequested());
      await bloc.stream.firstWhere((s) => s is RequestsLoaded);
      await sub.cancel();

      expect(states.first, const RequestsLoading());
      final loaded = states.last as RequestsLoaded;
      expect(loaded.requests.map((r) => r.id), ['2', '3', '4', '5', '6', '7'], reason: 'drafts are not in "all"');
      expect(loaded.filter, RequestsDashboardFilter.all);
      expect(loaded.counts['all'], 6);
      expect(loaded.counts['processing'], 2);
      expect(loaded.attentionCount, 1);
      expect(loaded.hasMore, isFalse);
      expect(repository.pageCalls.single.group, 'all');
      expect(repository.pageCalls.single.limit, 30);
    });

    test('a failed load is a RequestsFailure with the failure, flagged offline for a network error', () async {
      repository.pageFailure = const NetworkFailure('offline');
      bloc.add(const RequestsLoadRequested());
      final failed = await bloc.stream.firstWhere((s) => s is RequestsFailure) as RequestsFailure;

      expect(failed.offline, isTrue);
      expect(failed.failure, const NetworkFailure('offline'));
    });

    test('a reload keeps the selected group', () async {
      await load();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.filter == RequestsDashboardFilter.completed && !s.listLoading);

      repository.pageCalls.clear();
      bloc.add(const RequestsLoadRequested());
      final reloaded = await bloc.stream.firstWhere((s) => s is RequestsLoaded) as RequestsLoaded;

      expect(reloaded.filter, RequestsDashboardFilter.completed);
      expect(repository.pageCalls.single.group, 'completed');
    });
  });

  group('groups are filtered by the server', () {
    Future<RequestsLoaded> pick(RequestsDashboardFilter filter) async {
      await load();
      bloc.add(RequestsFilterChanged(filter));
      return await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.filter == filter && !s.listLoading) as RequestsLoaded;
    }

    test('pending / under review asks for the processing group', () async {
      final state = await pick(RequestsDashboardFilter.pendingUnderReview);
      expect(state.requests.map((r) => r.id), ['2', '3']);
      expect(repository.pageCalls.last.group, 'processing');
    });

    test('completed asks for the completed group', () async {
      final state = await pick(RequestsDashboardFilter.completed);
      expect(state.requests.map((r) => r.id), ['5']);
      expect(repository.pageCalls.last.group, 'completed');
    });

    test('action required asks for the action_needed group', () async {
      final state = await pick(RequestsDashboardFilter.actionRequired);
      expect(state.requests.map((r) => r.id), ['4']);
      expect(repository.pageCalls.last.group, 'action_needed');
    });

    test('the counts of every chip survive a change of chip', () async {
      final state = await pick(RequestsDashboardFilter.completed);
      expect(state.countFor(RequestsDashboardFilter.all), 6);
      expect(state.countFor(RequestsDashboardFilter.actionRequired), 1);
    });

    test('while the group loads the list is empty and flagged, not the previous group', () async {
      await load();
      repository.gate = Completer<void>();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      final loading = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.listLoading) as RequestsLoaded;
      expect(loading.requests, isEmpty);
      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && !s.listLoading);
    });

    test('choosing the same chip again does nothing', () async {
      await load();
      repository.pageCalls.clear();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.all));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.pageCalls, isEmpty);
    });

    test('a failed group load keeps the chip, empties the list and carries the failure', () async {
      await load();
      repository.pageFailure = const NetworkFailure('offline');
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      final failed = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.listFailure != null) as RequestsLoaded;

      expect(failed.filter, RequestsDashboardFilter.completed);
      expect(failed.listLoading, isFalse);
      expect(failed.requests, isEmpty);
    });

    test('only the last chip tapped lands (an older answer is dropped)', () async {
      await load();
      repository.gate = Completer<void>();
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.actionRequired));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      repository.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as RequestsLoaded;
      expect(state.filter, RequestsDashboardFilter.actionRequired);
      expect(state.requests.map((r) => r.id), ['4']);
    });
  });

  group('paging', () {
    List<RequestSummary> many(int n) => [
          for (var i = 0; i < n; i++) _summary('r$i', RequestStatus.processing),
        ];

    test('the first page is 30; more is requested with the loaded count as offset and appended', () async {
      repository.all = many(70);
      final first = await load();
      expect(first.requests, hasLength(30));
      expect(first.hasMore, isTrue);
      expect(first.counts['all'], 70);

      bloc.add(const RequestsLoadMoreRequested());
      final second = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.requests.length == 60) as RequestsLoaded;
      expect(repository.pageCalls.last.offset, 30);
      expect(second.hasMore, isTrue);

      bloc.add(const RequestsLoadMoreRequested());
      final third = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.requests.length == 70) as RequestsLoaded;
      expect(third.hasMore, isFalse);
      expect(third.requests.map((r) => r.id).toSet(), hasLength(70), reason: 'no id twice');
    });

    test('asking for more when there is none sends nothing', () async {
      await load();
      repository.pageCalls.clear();
      bloc.add(const RequestsLoadMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.pageCalls, isEmpty);
    });

    test('a burst of "more" events loads one page', () async {
      repository.all = many(100);
      await load();
      repository.pageCalls.clear();
      repository.gate = Completer<void>();
      for (var i = 0; i < 5; i++) {
        bloc.add(const RequestsLoadMoreRequested());
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repository.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.pageCalls, hasLength(1));
    });

    test('a failed page is flagged and can be tried again; the loaded rows stay', () async {
      repository.all = many(70);
      await load();
      repository.pageFailure = const NetworkFailure('offline');
      bloc.add(const RequestsLoadMoreRequested());
      final failed = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.loadMoreFailed) as RequestsLoaded;
      expect(failed.requests, hasLength(30));
      expect(failed.loadingMore, isFalse);

      repository.pageFailure = null;
      bloc.add(const RequestsLoadMoreRequested());
      final ok = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.requests.length == 60) as RequestsLoaded;
      expect(ok.loadMoreFailed, isFalse);
    });

    test('a page that arrives after the chip changed is dropped', () async {
      repository.all = many(70);
      await load();
      repository.gate = Completer<void>();
      bloc.add(const RequestsLoadMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const RequestsFilterChanged(RequestsDashboardFilter.completed));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      repository.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as RequestsLoaded;
      expect(state.filter, RequestsDashboardFilter.completed);
      expect(state.requests, isEmpty);
    });
  });

  group('search (done by the server)', () {
    test('sends the trimmed query to the server and shows its matches', () async {
      await load();
      repository.pageCalls.clear();
      bloc.add(const RequestsSearchChanged('  ahmed '));
      final done = await bloc.stream.firstWhere((s) => s is RequestsLoaded && !s.searching && s.searchResults.isNotEmpty) as RequestsLoaded;

      expect(done.searchResults.map((r) => r.id), ['4']);
      expect(repository.pageCalls.single.search, 'ahmed');
      expect(repository.pageCalls.single.group, 'all');
    });

    test('is flagged as searching while the server answers', () async {
      await load();
      repository.gate = Completer<void>();
      bloc.add(const RequestsSearchChanged('sb'));
      final searching = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.searching) as RequestsLoaded;
      expect(searching.searchQuery, 'sb');
      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && !s.searching);
    });

    test('no match gives an empty result, not the full list', () async {
      await load();
      bloc.add(const RequestsSearchChanged('does-not-exist'));
      final done = await bloc.stream.firstWhere((s) => s is RequestsLoaded && !s.searching && s.searchQuery.isNotEmpty) as RequestsLoaded;
      expect(done.searchResults, isEmpty);
    });

    test('a burst of keystrokes causes one search with the last query', () async {
      await load();
      repository.pageCalls.clear();
      for (final q in ['s', 'sb', 'sb-', 'sb-4']) {
        bloc.add(RequestsSearchChanged(q));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(RequestsBloc.searchDebounce + const Duration(milliseconds: 150));

      expect(repository.pageCalls, hasLength(1));
      expect(repository.pageCalls.single.search, 'sb-4');
      expect((bloc.state as RequestsLoaded).searchResults.map((r) => r.id), ['4']);
    });

    test('clearing the query empties the results at once, without a request', () async {
      await load();
      bloc.add(const RequestsSearchChanged('sb-4'));
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && !s.searching && s.searchResults.isNotEmpty);
      repository.pageCalls.clear();

      bloc.add(const RequestsSearchChanged(''));
      final cleared = await bloc.stream.first as RequestsLoaded;

      expect(cleared.searchResults, isEmpty);
      expect(cleared.searchQuery, '');
      expect(repository.pageCalls, isEmpty);
    });

    test('a failed search carries the failure and no results', () async {
      await load();
      repository.pageFailure = const NetworkFailure('offline');
      bloc.add(const RequestsSearchChanged('sb'));
      final failed = await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.searchFailure != null) as RequestsLoaded;

      expect(failed.searching, isFalse);
      expect(failed.searchResults, isEmpty);
    });
  });

  group('detail loading', () {
    test('RequestDetailRequested loads detail and sets detailReady', () async {
      await load();

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
      await load();
      bloc.add(const RequestDetailRequested('4'));
      await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailReady,
      );

      bloc.add(const RequestDetailAcknowledged());
      final state = await bloc.stream.first as RequestsLoaded;
      expect(state.detailReady, isFalse);
      expect(state.detail!.id, '4'); // detail itself is preserved
    });

    test('surfaces a detail load failure with the failure', () async {
      await load();

      repository.detailResult = const Left(ServerFailure('not found', code: 'request_not_found'));
      bloc.add(const RequestDetailRequested('4'));
      final failed = await bloc.stream.firstWhere(
        (s) => s is RequestsLoaded && s.detailStatus == RequestDetailStatus.failure,
      ) as RequestsLoaded;

      expect(failed.detailError, 'not found');
      expect((failed.detailFailure as ServerFailure).code, 'request_not_found');
    });
  });

  group('cancellation', () {
    Future<void> openDetail(String id) async {
      await load();
      bloc.add(RequestDetailRequested(id));
      await bloc.stream.firstWhere((s) => s is RequestsLoaded && s.detailReady);
    }

    Future<RequestsLoaded> cancel(String id) async {
      bloc.add(RequestCancelSubmitted(id));
      return await bloc.stream.firstWhere(
        (s) =>
            s is RequestsLoaded &&
            (s.cancelStatus == RequestCancelStatus.success ||
                s.cancelStatus == RequestCancelStatus.failure ||
                s.cancelStatus == RequestCancelStatus.notCancellable),
      ) as RequestsLoaded;
    }

    test('updates both the open detail and the dashboard row on success', () async {
      await openDetail('4');

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.success);
      expect(done.detail!.status, RequestStatus.cancelled);
      expect(done.requests.firstWhere((r) => r.id == '4').status, RequestStatus.cancelled);
    });

    test('when the cancellation went through but the reload failed, the request is shown cancelled', () async {
      await openDetail('4');
      repository.cancelResult = const Right(null);

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.success);
      expect(done.detail!.status, RequestStatus.cancelled);
    });

    test('after a timeout the request is read again, and found cancelled it counts as done (never resent)', () async {
      await openDetail('4');
      repository.cancelResult = const Left(NetworkFailure('timeout', isTimeout: true));
      repository.detailResult = Right(_detailFor('4', RequestStatus.cancelled));

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.success);
      expect(repository.cancelCalls, 1, reason: 'the cancellation is never sent twice');
    });

    test('after a timeout the request is read again, and found still open it is a failure', () async {
      await openDetail('4');
      repository.cancelResult = const Left(NetworkFailure('timeout', isTimeout: true));
      repository.detailResult = Right(_detailFor('4', RequestStatus.infoRequired));

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.failure);
      expect(done.cancelFailure, isA<NetworkFailure>());
      expect(repository.cancelCalls, 1);
    });

    test('a server error is treated like a timeout: the state is read before anything else', () async {
      await openDetail('4');
      repository.cancelResult = const Left(ServerFailure('boom', statusCode: 503));
      repository.detailResult = Right(_detailFor('4', RequestStatus.cancelled));

      expect((await cancel('4')).cancelStatus, RequestCancelStatus.success);
    });

    test('a refusal because the request cannot move to cancelled is "not cancellable"', () async {
      await openDetail('4');
      repository.cancelResult = const Left(ServerFailure('x', code: 'request_transition_invalid'));

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.notCancellable);
      expect(repository.detailCalls, 1, reason: 'only the detail opened at the start; no reread for a definite answer');
    });

    test('other refusals are failures that keep their failure for the localized message', () async {
      await openDetail('4');
      repository.cancelResult = const Left(ServerFailure('x', code: 'permission_denied'));

      final done = await cancel('4');

      expect(done.cancelStatus, RequestCancelStatus.failure);
      expect((done.cancelFailure as ServerFailure).code, 'permission_denied');
    });
  });
}
