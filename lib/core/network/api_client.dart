import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:http/http.dart' as http;

import 'access_token_store.dart';
import 'auth_interceptor.dart';
import 'auth_session_controller.dart';
import 'dio_http_client.dart';
import 'network_config.dart';
import 'refresh_coordinator.dart';
import 'session_remote_data_source.dart';

/// The one HTTP client of the app.
///
/// GraphQL goes through [graphqlHttpClient] (an adapter under the existing
/// `HttpLink`); REST file transfers use [dio] directly. Both share the cookie
/// jar (the `sb_refresh` cookie), the in-memory [tokens] and one
/// [RefreshCoordinator].
///
/// Interceptor order matters: the cookie manager is first, so on every response
/// the rotated cookie is stored *before* [AuthInterceptor] reads the answer.
class ApiClient {
  ApiClient._({
    required this.dio,
    required this.tokens,
    required this.coordinator,
    required this.sessionRemote,
    required this.cookieJar,
    required this.graphqlUri,
  });

  factory ApiClient.create({
    required CookieJar cookieJar,
    required AuthSessionController session,
    Uri? graphqlUri,
    AccessTokenStore? tokens,
    SessionRemoteDataSource? sessionRemote,
    HttpClientAdapter? adapter,
  }) {
    final uri = graphqlUri ?? Uri.parse(NetworkConfig.graphqlEndpoint);
    final dio = Dio(
      BaseOptions(
        connectTimeout: NetworkConfig.requestTimeout,
        sendTimeout: NetworkConfig.requestTimeout,
        receiveTimeout: NetworkConfig.requestTimeout,
        // Status codes are the caller's business (GraphQL answers 200 even for
        // errors; REST answers with a status and an error body).
        validateStatus: (_) => true,
        // A redirected POST would lose its body: treat any 3xx as an error.
        followRedirects: false,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;

    final store = tokens ?? AccessTokenStore();
    final remote = sessionRemote ?? DioSessionRemoteDataSource(dio: dio, graphqlUri: uri);
    final coordinator = RefreshCoordinator(tokens: store, remote: remote);
    dio.interceptors
      ..add(CookieManager(cookieJar, ignoreInvalidCookies: true))
      ..add(AuthInterceptor(tokens: store, coordinator: coordinator, session: session, dio: () => dio));

    return ApiClient._(
      dio: dio,
      tokens: store,
      coordinator: coordinator,
      sessionRemote: remote,
      cookieJar: cookieJar,
      graphqlUri: uri,
    );
  }

  final Dio dio;
  final AccessTokenStore tokens;
  final RefreshCoordinator coordinator;
  final SessionRemoteDataSource sessionRemote;
  final CookieJar cookieJar;
  final Uri graphqlUri;

  /// The `http.Client` the GraphQL `HttpLink` sends through.
  http.Client graphqlHttpClient() => DioHttpClient(dio: dio, graphqlUri: graphqlUri);
}
