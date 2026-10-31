// REST uploads (contract 8.1): multipart with a Content-Length, the access token,
// one refresh-and-resend on a dead token, the documented limits, and failures
// that carry the server's error code. No network.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/access_token_store.dart';
import 'package:seen_booking/core/network/api_client.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/network/file_upload_client.dart';
import 'package:seen_booking/core/network/strict_cookie_jar.dart';

import '../../support/fake_api_server.dart';

final _graphql = Uri.parse('https://api.seen.test/graphql/');

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody _error(int status, String code) => _json({
      'error': {'code': code, 'message': 'x'},
    }, status);

class _Rig {
  _Rig() {
    server = FakeServerAdapter((r) async {
      if (r.uri.path == '/files/upload/') {
        uploadCalls.add(r);
        if (uploadResponder != null) return uploadResponder!(r);
        if (r.authorization != 'Bearer ${backend.validToken}') return _error(401, 'not_authenticated');
        return _json({'id': 'doc-1', 'fileId': 'file-1', 'name': 'passport.jpg'}, 201);
      }
      if (r.uri.path == '/files/read-passport/') {
        passportCalls.add(r);
        if (passportResponder != null) return passportResponder!(r);
        if (r.authorization != 'Bearer ${backend.validToken}') return _error(401, 'not_authenticated');
        return _json({
          'allChecksPass': true,
          'suggestions': [
            {'key': 'passportNumber', 'value': 'N0849482', 'checked': true},
          ],
        }, 200);
      }
      return backend.call(r);
    });
    final jar = StrictPersistCookieJar(storage: MemoryCookieStorage());
    controller = AuthSessionController();
    sub = controller.events.listen(events.add);
    tokens = AccessTokenStore();
    api = ApiClient.create(cookieJar: jar, session: controller, graphqlUri: _graphql, tokens: tokens, adapter: server);
    client = FileUploadClient(dio: api.dio, coordinator: api.coordinator, session: controller, apiBase: _graphql);
  }

  final backend = FakeBackend();
  late final FakeServerAdapter server;
  late final AuthSessionController controller;
  late final StreamSubscription<AuthSessionEvent> sub;
  late final AccessTokenStore tokens;
  late final ApiClient api;
  late final FileUploadClient client;
  final events = <AuthSessionEvent>[];
  final uploadCalls = <RecordedRequest>[];
  FutureOr<ResponseBody> Function(RecordedRequest)? uploadResponder;
  final passportCalls = <RecordedRequest>[];
  FutureOr<ResponseBody> Function(RecordedRequest)? passportResponder;

  /// Signs in through the stack so the refresh cookie is in the jar.
  Future<void> signIn() async {
    await api.dio.postUri<dynamic>(_graphql, data: '{"query":"mutation Login { login }"}');
    tokens.set(backend.validToken);
  }

  Future<Either<Failure, UploadedFile>> upload(String path, {String name = 'passport.jpg'}) => client.upload(
        kind: 'document',
        path: path,
        fileName: name,
        fields: {'travelerId': 't-1', 'documentRequirementId': 'd-1'},
      );

  Future<void> dispose() => sub.cancel();
}

void main() {
  late Directory dir;
  late String jpg;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('upload_test');
    jpg = '${dir.path}${Platform.pathSeparator}passport.jpg';
    File(jpg).writeAsBytesSync(List.generate(2048, (i) => i % 251));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Failure leftOf(Either<Failure, UploadedFile> r) => (r as Left<Failure, UploadedFile>).value;

  group('a good upload', () {
    test('is multipart with Content-Length, the bearer token and the traveler / requirement fields', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();

      final result = await rig.upload(jpg);

      final file = (result as Right<Failure, UploadedFile>).value;
      expect(file.id, 'doc-1');
      expect(file.fileId, 'file-1');
      final request = rig.uploadCalls.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'https://api.seen.test/files/upload/');
      expect(request.authorization, 'Bearer ${rig.backend.validToken}');
      expect(request.header('content-type'), startsWith('multipart/form-data; boundary='));
      // Mandatory: the length of the whole body is declared (no chunked upload).
      expect(request.header('content-length'), '${request.body.length}');
      final text = latin1.decode(request.body);
      expect(text, contains('name="kind"'));
      expect(text, contains('document'));
      expect(text, contains('name="travelerId"'));
      expect(text, contains('name="documentRequirementId"'));
      expect(text, contains('name="file"; filename="passport.jpg"'));
      expect(text, contains('image/jpeg'));
    });

    test('a PDF and a PNG are sent with their own type', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final pdf = '${dir.path}${Platform.pathSeparator}a.pdf'..let((p) => File(p).writeAsBytesSync([37, 80, 68, 70, 45]));
      final png = '${dir.path}${Platform.pathSeparator}a.PNG'..let((p) => File(p).writeAsBytesSync([137, 80, 78, 71]));
      await rig.upload(pdf, name: 'a.pdf');
      await rig.upload(png, name: 'a.PNG');
      expect(latin1.decode(rig.uploadCalls[0].body), contains('application/pdf'));
      expect(latin1.decode(rig.uploadCalls[1].body), contains('image/png'));
    });
  });

  group('refused on the device, nothing is sent', () {
    test('a type the server does not take (SVG, GIF, no extension)', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      for (final name in ['x.svg', 'x.gif', 'x', 'x.html']) {
        final result = await rig.upload(jpg, name: name);
        expect((leftOf(result) as ServerFailure).code, 'file_type_not_allowed', reason: name);
      }
      expect(rig.uploadCalls, isEmpty);
    });

    test('an empty file', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final empty = '${dir.path}${Platform.pathSeparator}empty.jpg';
      File(empty).writeAsBytesSync(const []);
      expect((leftOf(await rig.upload(empty)) as ServerFailure).code, 'file_empty');
      expect(rig.uploadCalls, isEmpty);
    });

    test('a file over 8 MiB; exactly 8 MiB is accepted', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final big = '${dir.path}${Platform.pathSeparator}big.jpg';
      File(big).writeAsBytesSync(Uint8List(UploadLimits.maxBytes + 1));
      expect((leftOf(await rig.upload(big)) as ServerFailure).code, 'file_too_large');
      expect(rig.uploadCalls, isEmpty);

      File(big).writeAsBytesSync(Uint8List(UploadLimits.maxBytes));
      expect((await rig.upload(big)).isRight(), isTrue);
    });

    test('a file that is gone', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final result = await rig.upload('${dir.path}${Platform.pathSeparator}missing.jpg');
      expect((leftOf(result) as ServerFailure).code, 'file_unreadable');
    });
  });

  group('a dead access token', () {
    test('one refresh, then the upload is rebuilt and sent once more with the new token', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();

      final result = await rig.upload(jpg);

      expect(result.isRight(), isTrue);
      expect(rig.backend.refreshCalls, 1);
      expect(rig.uploadCalls, hasLength(2));
      expect(rig.uploadCalls[0].authorization, isNot(rig.uploadCalls[1].authorization));
      expect(rig.uploadCalls[1].authorization, 'Bearer ${rig.backend.validToken}');
      // The second body is complete (a FormData can only be sent once, so it was rebuilt).
      expect(rig.uploadCalls[1].body.length, rig.uploadCalls[0].body.length);
      expect(rig.uploadCalls[1].header('content-length'), '${rig.uploadCalls[1].body.length}');
    });

    test('the server ended the session: unauthorized, the app is told, no second upload', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();
      rig.backend.sessionAlive = false;

      final result = await rig.upload(jpg);

      expect(leftOf(result), isA<UnauthorizedFailure>());
      await pumpEventQueue();
      expect(rig.events, [AuthSessionEvent.unauthenticated]);
      expect(rig.uploadCalls, hasLength(1));
      expect(rig.backend.refreshCalls, 1);
    });

    test('a refresh that could not be completed is a network failure, not a sign-out', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();
      rig.backend.refreshGate = () async => throw const SocketException('down');

      final result = await rig.upload(jpg);

      expect(leftOf(result), isA<NetworkFailure>());
      expect(rig.events, isEmpty);
      expect(rig.uploadCalls, hasLength(1));
    });

    test('a token that keeps failing is not refreshed again and again', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.uploadResponder = (_) => _error(401, 'not_authenticated');

      final result = await rig.upload(jpg);

      expect(leftOf(result), isA<UnauthorizedFailure>());
      expect(rig.backend.refreshCalls, 1);
      expect(rig.uploadCalls, hasLength(2));
    });
  });

  group('failures carry the server code', () {
    Future<Failure> failWith(ResponseBody Function(RecordedRequest) responder) async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.uploadResponder = responder;
      return leftOf(await rig.upload(jpg));
    }

    test('400 with an error code', () async {
      final f = await failWith((_) => _error(400, 'file_content_mismatch')) as ServerFailure;
      expect(f.code, 'file_content_mismatch');
      expect(f.statusCode, 400);
    });

    test('404 for a request or traveler that is not available', () async {
      final f = await failWith((_) => _error(404, 'request_not_found')) as ServerFailure;
      expect(f.code, 'request_not_found');
    });

    test('413 is "too large" even without a body', () async {
      final f = await failWith((_) => ResponseBody.fromString('', 413)) as ServerFailure;
      expect(f.code, 'file_too_large');
    });

    test('429 is "too many attempts"', () async {
      final f = await failWith((_) => _error(429, 'too_many_attempts')) as ServerFailure;
      expect(f.code, 'too_many_attempts');
    });

    test('403 is forbidden', () async {
      final f = await failWith((_) => _error(403, 'permission_denied'));
      expect(f, isA<ForbiddenFailure>());
    });

    test('503 (the scanner or storage is off) is a server failure with its status', () async {
      final f = await failWith((_) => _error(503, 'upload_unavailable')) as ServerFailure;
      expect(f.statusCode, 503);
    });

    test('a proxy page instead of JSON is a server failure, never a crash', () async {
      final f = await failWith((_) => ResponseBody.fromString('<html>bad gateway</html>', 502)) as ServerFailure;
      expect(f.statusCode, 502);
    });

    test('a 201 without ids is refused as unexpected', () async {
      final f = await failWith((_) => _json({'ok': true}, 201));
      expect(f, isA<ServerFailure>());
    });
  });

  group('transport', () {
    test('a timeout is a timeout failure', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.uploadResponder = (r) => throw DioException(requestOptions: r.options, type: DioExceptionType.sendTimeout);
      final f = leftOf(await rig.upload(jpg)) as NetworkFailure;
      expect(f.isTimeout, isTrue);
    });

    test('no connection is a network failure', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.uploadResponder = (r) => throw DioException(
            requestOptions: r.options,
            type: DioExceptionType.connectionError,
            error: const SocketException('down'),
          );
      final f = leftOf(await rig.upload(jpg)) as NetworkFailure;
      expect(f.isTimeout, isFalse);
    });
  });

  group('reading a passport (contract 8.3)', () {
    test('posts one image to /files/read-passport/ with the token and returns the server\'s JSON', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();

      final result = await rig.client.readPassport(path: jpg, fileName: 'passport.jpg');

      final body = (result as Right<Failure, Map<String, dynamic>>).value;
      expect(body['allChecksPass'], isTrue);
      expect((body['suggestions'] as List).single['key'], 'passportNumber');
      final request = rig.passportCalls.single;
      expect(request.uri.toString(), 'https://api.seen.test/files/read-passport/');
      expect(request.authorization, 'Bearer ${rig.backend.validToken}');
      expect(request.header('content-type'), startsWith('multipart/form-data; boundary='));
      expect(request.header('content-length'), '${request.body.length}', reason: 'the length of the body is declared');
      final text = latin1.decode(request.body);
      expect(text, contains('name="file"; filename="passport.jpg"'));
      expect(text, isNot(contains('name="kind"')), reason: 'this endpoint takes the image only');
    });

    test('a PDF or another file type is refused before anything is sent', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final pdf = '${dir.path}${Platform.pathSeparator}scan.pdf';
      File(pdf).writeAsBytesSync([1, 2, 3]);
      final result = await rig.client.readPassport(path: pdf, fileName: 'scan.pdf');
      expect(((result as Left).value as ServerFailure).code, 'passport_not_image');
      expect(rig.passportCalls, isEmpty);
    });

    test('the server\'s own codes come through: not an image, reading unavailable, too many readings', () async {
      for (final (status, code) in [(400, 'passport_not_image'), (503, 'ocr_unavailable'), (429, 'too_many_attempts')]) {
        final rig = _Rig();
        addTearDown(rig.dispose);
        await rig.signIn();
        rig.passportResponder = (_) => _error(status, code);
        final result = await rig.client.readPassport(path: jpg, fileName: 'p.jpg');
        expect(((result as Left).value as ServerFailure).code, code, reason: '$status');
      }
    });

    test('a dead token is refreshed once and the reading is sent again', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.tokens.set('expired-token');
      final result = await rig.client.readPassport(path: jpg, fileName: 'p.jpg');
      expect(result.isRight(), isTrue);
      expect(rig.passportCalls, hasLength(2));
    });
  });
}

extension<T> on T {
  T let(void Function(T) f) {
    f(this);
    return this;
  }
}
