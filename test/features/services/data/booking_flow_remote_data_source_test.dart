// The booking calls against the backend contract: every document is validated
// against `docs/api/mobile-api-reference.md`, the variables are checked, and the
// parsers run on realistic answers.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/network/api_client.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/network/file_upload_client.dart';
import 'package:seen_booking/core/network/strict_cookie_jar.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/services/data/datasources/booking_flow_remote_data_source.dart';
import 'package:seen_booking/features/services/domain/entities/booking_document.dart';
import 'package:seen_booking/features/services/domain/entities/field_value_input.dart';

import '../../../support/fake_api_server.dart';
import '../../../support/scripted_graphql_service.dart';

Map<String, Object?> _review({
  bool canSubmit = true,
  bool holdDeferred = false,
  Object? violations = const [],
  List<String> errors = const [],
  Map<String, Object?> quote = const {},
}) =>
    {
      'portalDraftReview': {
        'requestId': 'req-1',
        'status': 'draft',
        'service': {'id': 'svc-1', 'nameAr': 'موافقة', 'nameEn': 'Approval'},
        'travelers': [
          {
            'id': 't1',
            'index': 0,
            'name': 'A*** S***',
            'nameMasked': true,
            'passportNumber': 'X***89',
            'documentsCount': 1,
          },
        ],
        'quote': {
          'currency': 'USD',
          'unitPrice': '85.00',
          'travelerCount': 1,
          'total': '85.00',
          'balance': '200.00',
          'availableAfter': '115.00',
          'creditLimit': '0.00',
          'fundsSufficient': true,
          'holdDeferred': holdDeferred,
          'slaHours': 48,
          ...quote,
        },
        'errors': errors,
        'violations': violations,
        'canSubmit': canSubmit,
      },
    };

BookingFlowRemoteDataSourceImpl _source(ScriptedGraphQLService graphql) {
  final api = ApiClient.create(
    cookieJar: StrictPersistCookieJar(storage: MemoryCookieStorage()),
    session: AuthSessionController(),
    graphqlUri: Uri.parse('https://api.seen.test/graphql/'),
    adapter: FakeServerAdapter((r) async => ResponseBody.fromString('{}', 500)),
  );
  return BookingFlowRemoteDataSourceImpl(
    graphQLService: graphql,
    uploads: FileUploadClient(
      dio: api.dio,
      coordinator: api.coordinator,
      session: AuthSessionController(),
      apiBase: api.graphqlUri,
    ),
    language: AppLanguage('en'),
  );
}

void main() {
  late ScriptedGraphQLService graphql;
  late BookingFlowRemoteDataSourceImpl source;

  void script(Map<String, Object> answers) {
    graphql = ScriptedGraphQLService(answers);
    source = _source(graphql);
  }

  test('createDraftRequest sends only the service id and returns the draft id', () async {
    script({
      'CreateDraftRequest': {
        'createDraftRequest': {'id': 'req-1', 'status': 'draft'},
      },
    });
    final result = await source.createDraft('svc-1');
    expect((result as Right).value, 'req-1');
    expect(graphql.where('CreateDraftRequest').single.variables, {'serviceTypeId': 'svc-1'});
  });

  test('batchAddTravelers sends {fieldDefinitionId, value} per traveler, in order', () async {
    script({
      'BatchAddTravelers': {
        'batchAddTravelers': [
          {'id': 't1'},
          {'id': 't2'},
        ],
      },
    });
    final result = await source.addTravelers('req-1', [
      const [FieldValueInput(fieldDefinitionId: 'f1', value: 'Amal'), FieldValueInput(fieldDefinitionId: 'f2', value: '1990-03-05')],
      const [FieldValueInput(fieldDefinitionId: 'f1', value: 'Omar')],
    ]);
    expect((result as Right).value, ['t1', 't2']);
    expect(graphql.where('BatchAddTravelers').single.variables, {
      'requestId': 'req-1',
      'travelers': [
        {
          'fieldValues': [
            {'fieldDefinitionId': 'f1', 'value': 'Amal'},
            {'fieldDefinitionId': 'f2', 'value': '1990-03-05'},
          ],
        },
        {
          'fieldValues': [
            {'fieldDefinitionId': 'f1', 'value': 'Omar'},
          ],
        },
      ],
    });
  });

  test('a validation_failed answer carries each problem with its traveler and field', () async {
    script({
      'BatchAddTravelers': const ValidationFailure('x', issues: [ValidationIssue(code: 'required', travelerIndex: 1, field: 'fullName')]),
    });
    final result = await source.addTravelers('req-1', [const []]);
    final failure = (result as Left).value as ValidationFailure;
    expect(failure.issues.single.travelerIndex, 1);
    expect(failure.issues.single.field, 'fullName');
  });

  test('portalDraftReview parses the quote into cents and the traveler lines', () async {
    script({'PortalDraftReview': _review()});
    final review = ((await source.reviewDraft('req-1')) as Right).value;
    expect(review.requestId, 'req-1');
    expect(review.serviceId, 'svc-1');
    expect(review.serviceName, 'Approval');
    expect(review.canSubmit, isTrue);
    expect(review.quote.unitPriceCents, 8500);
    expect(review.quote.totalCents, 8500);
    expect(review.quote.balanceCents, 20000);
    expect(review.quote.availableAfterCents, 11500);
    expect(review.quote.holdDeferred, isFalse);
    expect(review.quote.slaHours, 48);
    expect(review.travelers.single.nameMasked, isTrue);
    expect(review.travelers.single.documentsCount, 1);
    expect(graphql.where('PortalDraftReview').single.variables, {'requestId': 'req-1'});
  });

  test('violations (free JSON) are reduced to codes whatever their shape', () async {
    script({
      'PortalDraftReview': _review(
        canSubmit: false,
        errors: ['documents_missing'],
        violations: [
          {'code': 'passport_validity', 'traveler': 0},
          'age_rule',
        ],
      ),
    });
    var review = ((await source.reviewDraft('req-1')) as Right).value;
    expect(review.canSubmit, isFalse);
    expect(review.errors, ['documents_missing']);
    expect(review.violations, ['passport_validity', 'age_rule']);
    expect(review.hasBlockers, isTrue);

    script({
      'PortalDraftReview': _review(violations: {'quota_exceeded': true}),
    });
    review = ((await source.reviewDraft('req-1')) as Right).value;
    expect(review.violations, ['quota_exceeded']);

    script({'PortalDraftReview': _review(violations: null)});
    review = ((await source.reviewDraft('req-1')) as Right).value;
    expect(review.hasBlockers, isFalse);
  });

  test('a deferred hold and a missing price are carried as the server sent them', () async {
    script({
      'PortalDraftReview': _review(
        holdDeferred: true,
        quote: {'total': null, 'balance': null, 'fundsSufficient': null},
      ),
    });
    final quote = ((await source.reviewDraft('req-1')) as Right).value.quote;
    expect(quote.holdDeferred, isTrue);
    expect(quote.totalCents, isNull);
    expect(quote.balanceCents, isNull);
    expect(quote.fundsSufficient, isNull);
  });

  test('submitRequest reads the id, status and the reference code', () async {
    script({
      'SubmitRequest': {
        'submitRequest': {'id': 'req-1', 'referenceCode': 'SB-20481', 'status': 'pending_management_approval'},
      },
    });
    final result = ((await source.submit('req-1')) as Right).value;
    expect(result.requestId, 'req-1');
    expect(result.referenceCode, 'SB-20481');
    expect(result.status, RequestStatus.pendingManagementApproval);
    expect(result.hasReference, isTrue);
    expect(graphql.where('SubmitRequest').single.variables, {'requestId': 'req-1'});
  });

  test('submitRequest before the reference exists: empty code, no reference yet', () async {
    script({
      'SubmitRequest': {
        'submitRequest': {'id': 'req-1', 'referenceCode': '', 'status': 'submitted'},
      },
    });
    final result = ((await source.submit('req-1')) as Right).value;
    expect(result.hasReference, isFalse);
  });

  test('every failure of a call comes back as a Failure, never an exception', () async {
    script({'SubmitRequest': const ServerFailure('x', code: 'insufficient_funds', details: {'available': '40.00'})});
    final failure = ((await source.submit('req-1')) as Left).value as ServerFailure;
    expect(failure.code, 'insufficient_funds');
    expect(failure.details['available'], '40.00');
  });

  test('an upload with a refused file fails before any request, with the server vocabulary', () async {
    script(const {});
    final result = await source.uploadDocument(const BookingDocumentUpload(
      requestId: 'req-1',
      travelerId: 't1',
      requirementId: 'd1',
      document: PickedDocument(path: 'nowhere/x.svg', fileName: 'x.svg', sizeBytes: 10),
    ));
    expect(((result as Left).value as ServerFailure).code, 'file_type_not_allowed');
  });
}
