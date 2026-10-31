import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// A request as the fake server saw it.
class RecordedRequest {
  RecordedRequest(this.method, this.uri, this._headers, this.body, this.options);

  /// For answers that must fail like a transport would (`DioException`).
  final RequestOptions options;

  final String method;
  final Uri uri;
  final Map<String, String> _headers;
  final List<int> body;

  String? header(String name) => _headers[name.toLowerCase()];

  String? get authorization => header('authorization');

  String? get cookie => header('cookie');

  Map<String, dynamic>? get json {
    if (body.isEmpty) return null;
    final decoded = jsonDecode(utf8.decode(body));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// `Refresh`, `Logout`, `Wallet`, ... from `mutation Refresh {...}`.
  String? get operation {
    final query = json?['query'];
    if (query is! String) return null;
    return RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(query)?.group(1);
  }
}

typedef Responder = FutureOr<ResponseBody> Function(RecordedRequest request);

/// A Dio adapter that plays the backend: scripted answers, no network.
class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter(this.responder);

  Responder responder;
  final List<RecordedRequest> requests = [];

  List<RecordedRequest> where(String operation) => requests.where((r) => r.operation == operation).toList();

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    final headers = <String, String>{
      for (final e in options.headers.entries) e.key.toLowerCase(): e.value.toString(),
    };
    final recorded = RecordedRequest(options.method, options.uri, headers, body, options);
    requests.add(recorded);
    return responder(recorded);
  }

  @override
  void close({bool force = false}) {}
}

/// A GraphQL answer (HTTP 200 unless told otherwise).
ResponseBody gql(Object? body, {int status = 200, List<String> setCookies = const []}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookies.isNotEmpty) 'set-cookie': setCookies,
      },
    );

Map<String, Object?> gqlError(String code, {String message = 'x', Map<String, Object?>? params}) => {
      'data': null,
      'errors': [
        {
          'message': message,
          'extensions': {'code': code, if (params != null) 'params': params},
        },
      ],
    };

Map<String, Object?> refreshOk(String token) => {
      'data': {
        'refresh': {'accessToken': token},
      },
    };

/// `Set-Cookie` header as the backend sends it for the refresh cookie.
String refreshCookie(String value) => 'sb_refresh=$value; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=86400';

/// Cookie-jar storage kept in a map, so a "restart" is a new jar over the same map.
class MemoryCookieStorage extends Storage {
  MemoryCookieStorage([Map<String, String>? data]) : data = data ?? {};

  final Map<String, String> data;
  int inits = 0;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async => inits++;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> deleteAll(List<String> keys) async => data.clear();
}

/// A small model of the backend's session behaviour: an access token that can
/// be expired, a rotating refresh cookie, and "reusing a rotated cookie ends
/// the session" (contract section 3.4).
class FakeBackend {
  String validToken = 'token-0';
  String validRefresh = 'refresh-0';
  bool sessionAlive = true;
  String rejectCode = 'session_expired';
  int refreshCalls = 0;
  int logoutCalls = 0;
  int _n = 0;

  /// Awaited inside `Refresh`, to hold a refresh open or fail it.
  Future<void> Function()? refreshGate;

  /// The access token the app holds stops being accepted.
  void expireAccessToken() => validToken = 'expired-${_n++}';

  Future<ResponseBody> call(RecordedRequest r) async {
    switch (r.operation) {
      case 'Login':
        validToken = 'token-${++_n}';
        validRefresh = 'refresh-$_n';
        sessionAlive = true;
        return gql(refreshOk(validToken), setCookies: [refreshCookie(validRefresh)]);
      case 'Refresh':
        refreshCalls++;
        await refreshGate?.call();
        final cookie = r.cookie ?? '';
        if (!sessionAlive) return gql(gqlError(rejectCode));
        if (cookie.isEmpty) return gql(gqlError('no_refresh_session'));
        if (!cookie.contains('sb_refresh=$validRefresh')) {
          sessionAlive = false; // a rotated cookie was replayed
          return gql(gqlError(rejectCode));
        }
        validToken = 'token-${++_n}';
        validRefresh = 'refresh-$_n';
        return gql(refreshOk(validToken), setCookies: [refreshCookie(validRefresh)]);
      case 'Logout':
        logoutCalls++;
        return gql({
          'data': {'logout': true},
        }, setCookies: [
          'sb_refresh=; Max-Age=0; Path=/; HttpOnly; Secure'
        ]);
      default:
        if (r.authorization != 'Bearer $validToken') return gql(gqlError('not_authenticated'));
        return gql({
          'data': {'ok': true},
        });
    }
  }
}
