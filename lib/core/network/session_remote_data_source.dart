import 'package:dio/dio.dart';

import 'api_error_codes.dart';
import 'auth_interceptor.dart';

/// What a `refresh` call came back with.
sealed class RefreshResponse {
  const RefreshResponse();
}

/// A new access token. The rotated `sb_refresh` cookie was already stored.
final class RefreshSucceeded extends RefreshResponse {
  const RefreshSucceeded(this.accessToken);

  final String accessToken;
}

/// The server says the session is over (see [ApiErrorCodes.sessionEnded]).
final class RefreshRejected extends RefreshResponse {
  const RefreshRejected(this.code);

  final String code;
}

/// Anything else: timeout, no network, 5xx, rate limit, unreadable answer.
/// Whether the server rotated the token is unknown, so this is never retried
/// automatically.
final class RefreshUnavailable extends RefreshResponse {
  const RefreshUnavailable();
}

/// The two session operations the transport itself needs. Everything else is a
/// feature data source going through `GraphQLService`.
abstract interface class SessionRemoteDataSource {
  Future<RefreshResponse> refresh();

  /// Asks the server to end the session (blacklist the refresh token, clear
  /// the cookie). Throws on failure; callers treat failure as best effort.
  Future<void> logout();
}

class DioSessionRemoteDataSource implements SessionRemoteDataSource {
  DioSessionRemoteDataSource({required Dio dio, required Uri graphqlUri})
      : _dio = dio,
        _uri = graphqlUri;

  final Dio _dio;
  final Uri _uri;

  static const _refreshDocument = 'mutation Refresh { refresh { accessToken } }';
  static const _logoutDocument = 'mutation Logout { logout }';

  Future<Response<dynamic>> _post(String document) => _dio.postUri<dynamic>(
        _uri,
        data: {'query': document},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          // No access token and no refresh-on-failure: the cookie is the
          // credential and a failure here must not trigger another refresh.
          extra: {AuthInterceptor.skipAuthKey: true},
        ),
      );

  @override
  Future<RefreshResponse> refresh() async {
    try {
      final response = await _post(_refreshDocument);
      if (response.statusCode != 200) return const RefreshUnavailable();
      final body = response.data;
      final codes = ApiErrorCodes.codesOf(body);
      for (final code in codes) {
        if (ApiErrorCodes.sessionEnded.contains(code)) return RefreshRejected(code);
      }
      if (codes.isNotEmpty) return const RefreshUnavailable();
      final data = body is Map ? body['data'] : null;
      final result = data is Map ? data['refresh'] : null;
      final token = result is Map ? result['accessToken'] : null;
      if (token is String && token.isNotEmpty) return RefreshSucceeded(token);
      return const RefreshUnavailable();
    } catch (_) {
      return const RefreshUnavailable();
    }
  }

  @override
  Future<void> logout() async {
    final response = await _post(_logoutDocument);
    if (response.statusCode != 200) {
      throw DioException(requestOptions: response.requestOptions, response: response, message: 'logout failed');
    }
  }
}
