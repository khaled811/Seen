// The requests data source against the backend contract: documents validated
// against `docs/api/mobile-api-reference.md`, mapping run on realistic answers.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/requests/data/datasources/requests_remote_data_source.dart';
import 'package:seen_booking/features/requests/data/repositories/requests_repository_impl.dart';
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, dynamic> _card(String id, String status, {String? deadline, String amount = '150.00'}) => {
      'id': id,
      'referenceCode': 'SB-$id',
      'status': status,
      'statusGroup': 'processing',
      'serviceNameAr': 'تأشيرة مصر',
      'serviceNameEn': 'Egypt visa',
      'travelerCount': 2,
      'travelerNames': ['A*** S***', 'M*** K***'],
      'amount': amount,
      'deadlineAt': deadline,
      'createdAt': '2026-10-17T10:00:00+00:00',
    };

Map<String, Object> _answers() => {
      'PortalRequests': {
        'portalRequests': {
          'items': [
            _card('r1', 'info_required', deadline: '2026-10-20T10:00:00+00:00'),
            _card('r2', 'processing', deadline: '2026-10-22T10:00:00+00:00', amount: '99.50'),
          ],
          'total': 2,
          'hasMore': false,
          'filters': [
            {'key': 'all', 'count': 5},
            {'key': 'processing', 'count': 2},
            {'key': 'action_needed', 'count': 1},
          ],
          'attention': {'count': 1, 'soonestRemainingSeconds': 3600},
          'hasAnyRequests': true,
          'canCreate': true,
        },
      },
      'PortalRequestTracking': {
        'portalRequestTracking': {
          'request': _card('r1', 'info_required', deadline: '2026-10-20T10:00:00+00:00'),
          'filedAt': '2026-10-17T09:00:00+00:00',
          'feeTotal': '300.00',
          'timeline': [
            {'key': 'submitted', 'state': 'done', 'at': '2026-10-17T09:00:00+00:00'},
            {'key': 'under_review', 'state': 'current', 'at': '2026-10-17T11:00:00+00:00'},
            {'key': 'completed', 'state': 'pending', 'at': null},
            {'key': 'mystery_step', 'state': 'done', 'at': '2026-10-17T12:00:00+00:00'},
          ],
          'infoRequest': {
            'message': 'Passport photo is unclear',
            'deadlineAt': '2026-10-20T08:00:00+00:00',
          },
          'terminal': null,
          'travelers': [
            {'name': 'A*** S***', 'status': 'pending'},
          ],
          'outputs': [
            {'fileId': 'f1', 'fileName': 'visa.pdf', 'contentType': 'application/pdf', 'sizeBytes': 2048},
          ],
          'actions': {
            'canCancel': true,
            'cancelReleasesFunds': true,
            'canAddDocuments': true,
            'canViewDocuments': true,
            'canDownloadResult': false,
            'canDecideApproval': false,
            'canContactSupport': true,
          },
        },
      },
      'CancelRequest': {
        'cancelRequest': {'id': 'r1', 'status': 'cancelled'},
      },
    };

void main() {
  late ScriptedGraphQLService service;
  late RequestsRepositoryImpl repo;
  late AppLanguage language;

  setUp(() {
    service = ScriptedGraphQLService(_answers());
    language = AppLanguage('en');
    repo = RequestsRepositoryImpl(remote: RequestsRemoteDataSourceImpl(graphQLService: service, language: language));
  });

  group('the list', () {
    test('maps cards to rows: reference, localized service, Decimal amount, deadline only while info is required', () async {
      final page = (await repo.getRequests()).toNullable()!;

      final first = page.items[0];
      expect((first.id, first.referenceId, first.serviceName), ('r1', 'SB-r1', 'Egypt visa'));
      expect(first.status, RequestStatus.infoRequired);
      expect(first.slaDeadline, DateTime.parse('2026-10-20T10:00:00+00:00'));
      expect(first.totalPriceCents, 15000);
      expect(first.travelerNames, ['A*** S***', 'M*** K***']);
      final second = page.items[1];
      expect(second.totalPriceCents, 9950);
      expect(second.slaDeadline, isNull, reason: 'a deadline is shown only while the agency owes information');
    });

    test('carries the whole-list numbers the dashboard shows', () async {
      final page = (await repo.getRequests(group: 'processing')).toNullable()!;

      expect(page.counts, {'all': 5, 'processing': 2, 'action_needed': 1});
      expect((page.attentionCount, page.attentionSoonestSeconds), (1, 3600));
      expect((page.total, page.hasMore, page.hasAnyRequests, page.canCreate), (2, false, true, true));
    });

    test('sends the group, the trimmed search and the paging as variables', () async {
      await repo.getRequests(group: 'completed', search: '  SB-1 ', offset: 60, limit: 30);

      expect(service.where('PortalRequests').single.variables, {
        'group': 'completed',
        'search': 'SB-1',
        'limit': 30,
        'offset': 60,
      });
    });

    test('an empty search is not sent', () async {
      await repo.getRequests(search: '   ');

      expect(service.where('PortalRequests').single.variables['search'], isNull);
    });

    test('the service name follows the app language', () async {
      language.code = 'ar';

      final page = (await repo.getRequests()).toNullable()!;

      expect(page.items.first.serviceName, 'تأشيرة مصر');
    });

    test('an unknown status never crashes: it stays unknown', () async {
      final odd = ScriptedGraphQLService({
        'PortalRequests': {
          'portalRequests': {
            'items': [_card('r9', 'something_new')],
            'total': 1,
            'hasMore': false,
            'filters': <Object>[],
            'attention': {'count': 0, 'soonestRemainingSeconds': null},
            'hasAnyRequests': true,
            'canCreate': true,
          },
        },
      });
      final page = (await RequestsRepositoryImpl(
        remote: RequestsRemoteDataSourceImpl(graphQLService: odd, language: language),
      ).getRequests())
          .toNullable()!;

      expect(page.items.single.status, RequestStatus.unknown);
    });
  });

  group('the detail', () {
    test('maps tracking: fee, filing date, info deadline and message, travelers, outputs and the server actions', () async {
      final detail = (await repo.getRequestDetail('r1')).toNullable()!;

      expect((detail.id, detail.referenceId, detail.serviceName), ('r1', 'SB-r1', 'Egypt visa'));
      expect(detail.status, RequestStatus.infoRequired);
      expect(detail.totalPriceCents, 30000);
      expect(detail.submittedAt, DateTime.parse('2026-10-17T09:00:00+00:00'));
      expect(detail.slaDeadline, DateTime.parse('2026-10-20T08:00:00+00:00'), reason: 'the info request deadline wins');
      expect(detail.infoRequestMessage, 'Passport photo is unclear');
      expect(detail.travelers.single.name, 'A*** S***');
      expect(detail.outputs.single.fileId, 'f1');
      expect(detail.actions?.canCancel, isTrue);
      expect(detail.actions?.cancelReleasesFunds, isTrue);
      expect(detail.actions?.canDownloadResult, isFalse);
    });

    test('only reached steps with a known key become timeline entries', () async {
      final detail = (await repo.getRequestDetail('r1')).toNullable()!;

      expect(detail.timeline.map((e) => e.status), [RequestStatus.submitted, RequestStatus.underReview]);
    });

    test('cancellability comes from the server flag, not from a status table', () async {
      final detail = (await repo.getRequestDetail('r1')).toNullable()!;
      expect(detail.isCancellable, isTrue);

      final locked = ScriptedGraphQLService({
        'PortalRequestTracking': {
          'portalRequestTracking': {
            ...(_answers()['PortalRequestTracking'] as Map<String, dynamic>)['portalRequestTracking'] as Map<String, dynamic>,
            'actions': {'canCancel': false},
          },
        },
      });
      final notCancellable = (await RequestsRepositoryImpl(
        remote: RequestsRemoteDataSourceImpl(graphQLService: locked, language: language),
      ).getRequestDetail('r1'))
          .toNullable()!;
      expect(notCancellable.status, RequestStatus.infoRequired, reason: 'a status the old table would have allowed');
      expect(notCancellable.isCancellable, isFalse);
    });

    test('rejected and cancelled requests carry the terminal reason', () async {
      Map<String, dynamic> withTerminal(String status, Map<String, dynamic> terminal) => {
            'portalRequestTracking': {
              ...(_answers()['PortalRequestTracking'] as Map<String, dynamic>)['portalRequestTracking'] as Map<String, dynamic>,
              'request': _card('r1', status),
              'terminal': terminal,
              'infoRequest': null,
            },
          };
      RequestsRepositoryImpl repoFor(Map<String, dynamic> answer) => RequestsRepositoryImpl(
            remote: RequestsRemoteDataSourceImpl(
              graphQLService: ScriptedGraphQLService({'PortalRequestTracking': answer}),
              language: language,
            ),
          );

      final rejected = (await repoFor(withTerminal('rejected', {'kind': 'rejected', 'at': '2026-10-18T10:00:00+00:00', 'reason': 'Photo unclear'}))
              .getRequestDetail('r1'))
          .toNullable()!;
      expect(rejected.rejectionReason, 'Photo unclear');
      expect(rejected.cancellation, isNull);

      final cancelled = (await repoFor(withTerminal('cancelled', {'kind': 'cancelled', 'at': '2026-10-18T10:00:00+00:00', 'reason': 'customer_cancelled'}))
              .getRequestDetail('r1'))
          .toNullable()!;
      expect(cancelled.cancellation?.reason, 'customer_cancelled');
      expect(cancelled.cancellation?.cancelledAt, DateTime.parse('2026-10-18T10:00:00+00:00'));
      expect(cancelled.rejectionReason, isNull);
    });

    test('a request outside the agency (null) reads as "not found"', () async {
      final missing = ScriptedGraphQLService({
        'PortalRequestTracking': {'portalRequestTracking': null},
      });
      final result = await RequestsRepositoryImpl(
        remote: RequestsRemoteDataSourceImpl(graphQLService: missing, language: language),
      ).getRequestDetail('nope');

      expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, 'request_not_found');
    });
  });

  group('cancelling', () {
    test('sends a free-text reason, then reloads the request and returns the new detail', () async {
      final result = await repo.cancelRequest('r1', reason: CancelReason.dataError);

      expect(service.where('CancelRequest').single.variables, {'requestId': 'r1', 'reason': 'data_error'});
      expect(service.where('PortalRequestTracking'), hasLength(1));
      expect(result.toNullable(), isNotNull);
    });

    test('without a picked reason the reason is "other"', () async {
      await repo.cancelRequest('r1');

      expect(service.where('CancelRequest').single.variables['reason'], 'other');
    });

    test('if the reload fails the cancellation still counts and the answer is null', () async {
      final noDetail = ScriptedGraphQLService({
        'CancelRequest': _answers()['CancelRequest']!,
        'PortalRequestTracking': const NetworkFailure('offline'),
      });
      final result = await RequestsRepositoryImpl(
        remote: RequestsRemoteDataSourceImpl(graphQLService: noDetail, language: language),
      ).cancelRequest('r1');

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), isNull);
    });

    test('a refusal is passed on with its code and nothing is reloaded', () async {
      final refused = ScriptedGraphQLService({'CancelRequest': const ServerFailure('x', code: 'request_transition_invalid')});
      final result = await RequestsRepositoryImpl(
        remote: RequestsRemoteDataSourceImpl(graphQLService: refused, language: language),
      ).cancelRequest('r1');

      expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, 'request_transition_invalid');
      expect(refused.where('PortalRequestTracking'), isEmpty);
    });
  });

  test('an approver cannot be reminded: there is no operation and nothing is sent', () async {
    final result = await repo.remindApprover('r1');

    expect(((result as Left<Failure, dynamic>).value as ServerFailure).code, RequestsRemoteDataSourceImpl.unsupportedCode);
    expect(service.sent, isEmpty);
  });
}
