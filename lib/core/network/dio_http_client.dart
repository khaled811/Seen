import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import 'auth_interceptor.dart';

/// An `http.Client` that sends through [Dio].
///
/// The GraphQL `HttpLink` accepts any `http.Client`, so this lets the existing
/// GraphQL stack run on the shared [Dio] (cookie jar, auth, refresh) without
/// changing `GraphQLService`, the data sources or anything above them.
///
/// Errors are re-thrown as the exception types the failure mapper already
/// understands: [TimeoutException] for timeouts, [SocketException] for network
/// failures. `Set-Cookie` is never passed upward.
class DioHttpClient extends http.BaseClient {
  DioHttpClient({required Dio dio, required Uri graphqlUri})
      : _dio = dio,
        _graphqlUri = graphqlUri;

  final Dio _dio;
  final Uri _graphqlUri;

  bool _isGraphql(Uri url) => url.host == _graphqlUri.host && _trimSlash(url.path) == _trimSlash(_graphqlUri.path);

  static String _trimSlash(String path) => path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    // Dio recomputes the length from the bytes it sends.
    final headers = {
      for (final e in request.headers.entries)
        if (e.key.toLowerCase() != HttpHeaders.contentLengthHeader) e.key: e.value,
    };
    try {
      // `request` (not `fetch`) so the client-wide timeouts, `validateStatus`
      // and redirect settings of [_dio] apply.
      final response = await _dio.request<List<int>>(
        request.url.toString(),
        data: body.isEmpty ? null : body,
        options: Options(
          method: request.method,
          headers: headers,
          responseType: ResponseType.bytes,
          extra: {AuthInterceptor.graphqlKey: _isGraphql(request.url)},
        ),
      );
      final bytes = response.data ?? const <int>[];
      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        response.statusCode ?? 0,
        contentLength: bytes.length,
        request: request,
        headers: _flatten(response.headers),
        reasonPhrase: response.statusMessage,
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  static Map<String, String> _flatten(Headers headers) => {
        for (final e in headers.map.entries)
          if (e.key.toLowerCase() != HttpHeaders.setCookieHeader) e.key: e.value.join(', '),
      };

  static Object _translate(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException('The request timed out.');
      case DioExceptionType.connectionError:
        final inner = e.error;
        return inner is SocketException ? inner : const SocketException('No network connection.');
      case DioExceptionType.badCertificate:
        return http.ClientException('The server certificate was rejected.');
      case DioExceptionType.cancel:
        return http.ClientException('The request was cancelled.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is SocketException || inner is TimeoutException) return inner!;
        // Do not forward e.message: it can echo request details.
        return http.ClientException('The request failed.');
    }
  }
}
