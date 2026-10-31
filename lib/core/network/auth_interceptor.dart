import 'dart:io';

import 'package:dio/dio.dart';

import 'access_token_store.dart';
import 'api_error_codes.dart';
import 'auth_session_controller.dart';
import 'refresh_coordinator.dart';

/// Attaches the in-memory access token and recovers from an expired one.
///
/// - Before a request: a token older than [AccessTokenStore.staleAfter] is
///   refreshed first (checked on use, no background timer).
/// - After a GraphQL response carrying `not_authenticated` (HTTP 200): one
///   shared refresh, then the request is replayed **once** with the new token.
///   If the refresh could not be completed for a transient reason the request
///   fails as a network error instead of pretending the session ended.
/// - A refresh the server rejects ends the session through
///   [AuthSessionController].
///
/// Requests flagged `skipAuth` (the refresh and logout calls themselves) are
/// left alone, so recovery can never recurse.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AccessTokenStore tokens,
    required RefreshCoordinator coordinator,
    required AuthSessionController session,
    required Dio Function() dio,
  })  : _tokens = tokens,
        _coordinator = coordinator,
        _session = session,
        _dio = dio;

  /// `RequestOptions.extra` keys.
  static const String skipAuthKey = 'skipAuth';
  static const String graphqlKey = 'graphql';
  static const String _replayedKey = 'replayed';
  static const String _generationKey = 'tokenGeneration';

  final AccessTokenStore _tokens;
  final RefreshCoordinator _coordinator;
  final AuthSessionController _session;
  final Dio Function() _dio;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] == true) return handler.next(options);

    if (_tokens.isStale && options.extra[_replayedKey] != true) {
      final status = await _coordinator.refresh();
      if (status == RefreshStatus.sessionEnded) _session.notifyUnauthenticated();
    }

    final token = _tokens.token;
    if (token != null) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      options.extra[_generationKey] = _tokens.generation;
    } else {
      options.headers.remove(HttpHeaders.authorizationHeader);
      options.extra.remove(_generationKey);
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;
    final sentWith = options.extra[_generationKey];
    final eligible = options.extra[graphqlKey] == true &&
        options.extra[skipAuthKey] != true &&
        options.extra[_replayedKey] != true &&
        sentWith is int &&
        response.statusCode == 200 &&
        _isNotAuthenticated(response.data);
    if (!eligible) return handler.next(response);

    if (_tokens.generation == sentWith) {
      // Nobody has refreshed or signed out since this request left.
      switch (await _coordinator.refresh()) {
        case RefreshStatus.refreshed:
          break;
        case RefreshStatus.sessionEnded:
          _session.notifyUnauthenticated();
          return handler.next(response);
        case RefreshStatus.failed:
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const SocketException('The session could not be refreshed right now.'),
            ),
          );
      }
    } else if (!_tokens.hasToken) {
      // The session ended (sign-out or rejected refresh) while this was in flight.
      return handler.next(response);
    }
    // else: another request already refreshed; just use the current token.

    options.extra[_replayedKey] = true;
    try {
      handler.resolve(await _dio().fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  static bool _isNotAuthenticated(Object? data) {
    if (data is! List<int>) return false;
    return ApiErrorCodes.bytesContainCode(data, ApiErrorCodes.notAuthenticated);
  }
}
