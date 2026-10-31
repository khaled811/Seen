// "Upload the missing document" against the contract: one document validated
// against `docs/api/mobile-api-reference.md`, targets built from the service's
// document requirements and what each traveler already has.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/network/api_client.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/network/file_upload_client.dart';
import 'package:seen_booking/core/network/strict_cookie_jar.dart';
import 'package:seen_booking/features/requests/data/datasources/missing_document_remote_data_source.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';

import '../../../support/fake_api_server.dart';
import '../../../support/scripted_graphql_service.dart';

Map<String, Object?> _answer({
  Object? info = const {'message': 'The passport photo is unclear', 'deadlineAt': '2026-10-21T10:00:00+00:00', 'remainingSeconds': 3600},
  List<Map<String, Object?>>? documents,
}) =>
    {
      'portalRequestTracking': {
        'request': {'id': 'r1', 'referenceCode': 'SB-20476'},
        'infoRequest': info,
        'travelers': [
          {'id': 't1', 'index': 0, 'name': 'A*** S***', 'nameMasked': true},
          {'id': 't2', 'index': 1, 'name': 'M*** K***', 'nameMasked': true},
        ],
      },
      'request': {
        'serviceType': {
          'documents': documents ??
              [
                {'id': 'd-passport', 'labelAr': 'جواز', 'labelEn': 'Passport', 'required': true},
                {'id': 'd-photo', 'labelAr': 'صورة', 'labelEn': 'Photo', 'required': false},
              ],
        },
        'travelers': [
          {
            'id': 't1',
            'documents': [
              {
                'documentRequirement': {'id': 'd-passport'},
              },
            ],
          },
          {'id': 't2', 'documents': []},
        ],
      },
    };

MissingDocumentRemoteDataSourceImpl _source(ScriptedGraphQLService graphql, List<RecordedRequest> uploads) {
  final api = ApiClient.create(
    cookieJar: StrictPersistCookieJar(storage: MemoryCookieStorage()),
    session: AuthSessionController(),
    graphqlUri: Uri.parse('https://api.seen.test/graphql/'),
    adapter: FakeServerAdapter((r) async {
      uploads.add(r);
      return ResponseBody.fromString('{"id":"d1","fileId":"f1","name":"x.jpg"}', 201, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
    }),
  );
  return MissingDocumentRemoteDataSourceImpl(
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
  test('builds the places a file can go: still-missing ones first, in traveler then document order', () async {
    final graphql = ScriptedGraphQLService({'MissingDocumentRequest': _answer()});
    final result = await _source(graphql, []).getMissingDocument('r1');
    final request = (result as Right<Failure, MissingDocumentRequest>).value;

    expect(request.requestId, 'r1');
    expect(request.referenceId, 'SB-20476');
    expect(request.reason, 'The passport photo is unclear');
    expect(request.deadline, DateTime.parse('2026-10-21T10:00:00+00:00'));
    expect(request.hasChoice, isTrue);
    expect(request.maxBytes, 8 * 1024 * 1024);
    expect(request.allowedExtensions, ['pdf', 'jpg', 'jpeg', 'png']);
    expect([
      for (final t in request.targets) (t.travelerId, t.requirementId, t.alreadyUploaded),
    ], [
      ('t1', 'd-photo', false),
      ('t2', 'd-passport', false),
      ('t2', 'd-photo', false),
      ('t1', 'd-passport', true),
    ]);
    expect(request.targets.first.requirementLabel, 'Photo');
    expect(request.targets.first.travelerLabel, 'A*** S***');
    expect(graphql.where('MissingDocumentRequest').single.variables, {'requestId': 'r1'});
  });

  test('without a deadline date the remaining seconds give one', () async {
    final graphql = ScriptedGraphQLService({
      'MissingDocumentRequest': _answer(info: {'message': 'm', 'deadlineAt': null, 'remainingSeconds': 7200}),
    });
    final before = DateTime.now();
    final request = ((await _source(graphql, []).getMissingDocument('r1')) as Right<Failure, MissingDocumentRequest>).value;
    expect(request.deadline!.difference(before).inSeconds, inInclusiveRange(7199, 7210));
  });

  test('without any deadline there is none', () async {
    final graphql = ScriptedGraphQLService({
      'MissingDocumentRequest': _answer(info: {'message': 'm', 'deadlineAt': null, 'remainingSeconds': null}),
    });
    final request = ((await _source(graphql, []).getMissingDocument('r1')) as Right<Failure, MissingDocumentRequest>).value;
    expect(request.deadline, isNull);
  });

  test('a request that is not asking for anything is a failure, not a made-up screen', () async {
    final graphql = ScriptedGraphQLService({'MissingDocumentRequest': _answer(info: null)});
    final result = await _source(graphql, []).getMissingDocument('r1');
    expect(((result as Left).value as ServerFailure).code, 'not_info_required');
  });

  test('a service with no document requirements has nowhere to attach a file', () async {
    final graphql = ScriptedGraphQLService({'MissingDocumentRequest': _answer(documents: [])});
    final result = await _source(graphql, []).getMissingDocument('r1');
    expect(result.isLeft(), isTrue);
  });

  test('a request outside the caller scope (null) is a failure', () async {
    final graphql = ScriptedGraphQLService({
      'MissingDocumentRequest': {'portalRequestTracking': null, 'request': null},
    });
    expect((await _source(graphql, []).getMissingDocument('r1')).isLeft(), isTrue);
  });

  test('the load fails as a Failure when the server does', () async {
    final graphql = ScriptedGraphQLService({'MissingDocumentRequest': const NetworkFailure('off')});
    final result = await _source(graphql, []).getMissingDocument('r1');
    expect((result as Left).value, isA<NetworkFailure>());
  });

  test('a file sent to a target carries the traveler and the requirement, and reports progress', () async {
    final dir = Directory.systemTemp.createTempSync('missing_doc_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}x.jpg')..writeAsBytesSync(List.filled(4096, 7));
    final uploads = <RecordedRequest>[];
    final source = _source(ScriptedGraphQLService(const {}), uploads);
    final progress = <double>[];

    final result = await source.upload(
      target: const UploadTarget(travelerId: 't2', requirementId: 'd-passport', requirementLabel: 'Passport'),
      document: PickedDocument(path: file.path, fileName: 'x.jpg', sizeBytes: 4096),
      onProgress: progress.add,
    );

    expect(result.isRight(), isTrue);
    final text = String.fromCharCodes(uploads.single.body);
    expect(text, contains('name="travelerId"'));
    expect(text, contains('t2'));
    expect(text, contains('name="documentRequirementId"'));
    expect(text, contains('d-passport'));
    expect(text, contains('document'));
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });

  test('a file that is gone fails before anything is sent', () async {
    final uploads = <RecordedRequest>[];
    final source = _source(ScriptedGraphQLService(const {}), uploads);
    final result = await source.upload(
      target: const UploadTarget(travelerId: 't2', requirementId: 'd-passport', requirementLabel: 'Passport'),
      document: const PickedDocument(path: 'does/not/exist.jpg', fileName: 'x.jpg', sizeBytes: 5),
    );
    expect(((result as Left).value as ServerFailure).code, 'file_unreadable');
    expect(uploads, isEmpty);
  });
}
