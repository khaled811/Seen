import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

import '../constants/storage_keys.dart';
import 'auth_session_controller.dart';
import 'network_config.dart';

/// Builds and owns the app's single [GraphQLClient].
///
/// Link chain (outermost first):
/// [AuthLink] attaches the bearer token read from secure storage ->
/// [ErrorLink] observes transport/GraphQL errors and reports 401/403 to
/// [AuthSessionController] (without acting on them itself) ->
/// [HttpLink] (terminal) executes the HTTP request.
///
/// Owns the underlying [http.Client] via the link chain; call [dispose] once,
/// from the composition root, when the app/DI scope is torn down.
class GraphQLClientFactory {
  GraphQLClientFactory({
    required this.authSessionController,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AuthSessionController authSessionController;
  final FlutterSecureStorage _secureStorage;

  GraphQLClient? _client;

  /// The shared client, built lazily on first access.
  GraphQLClient get client => _client ??= _build();

  GraphQLClient _build() {
    final httpLink = HttpLink(
      NetworkConfig.graphqlEndpoint,
      httpClient: _TimeoutHttpClient(
        inner: http.Client(),
        timeout: NetworkConfig.requestTimeout,
      ),
    );

    final authLink = AuthLink(
      getToken: () async {
        final token = await _secureStorage.read(key: StorageKeys.authToken);
        return token == null ? null : 'Bearer $token';
      },
    );

    final errorLink = ErrorLink(
      onException: (request, forward, exception) {
        final statusCode =
            exception is HttpLinkServerException ? exception.response.statusCode : null;
        if (statusCode == 401) {
          authSessionController.notifyUnauthenticated();
        } else if (statusCode == 403) {
          authSessionController.notifyForbidden();
        }
        // Returning null lets the original exception propagate — the caller
        // (`GraphQLService`) still needs it to build an `Either<Failure, T>`.
        return null;
      },
      onGraphQLError: (request, forward, response) {
        for (final error in response.errors ?? const <GraphQLError>[]) {
          switch (error.extensions?['code']) {
            case 'UNAUTHENTICATED':
              authSessionController.notifyUnauthenticated();
            case 'FORBIDDEN':
              authSessionController.notifyForbidden();
          }
        }
        return null;
      },
    );

    return GraphQLClient(
      link: Link.from([authLink, errorLink, httpLink]),
      // In-memory cache for now; revisit (HiveStore + initHiveForFlutter)
      // once an explicit caching strategy is needed.
      cache: GraphQLCache(),
    );
  }

  /// Closes the underlying HTTP client. Call exactly once, from the
  /// composition root, on app/DI teardown — never mid-app-lifetime.
  Future<void> dispose() => _client?.link.dispose() ?? Future<void>.value();
}

/// Wraps [inner] to enforce [timeout] on every request, since `HttpLink` has
/// no built-in timeout support.
class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient({required this.inner, required this.timeout});

  final http.Client inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      inner.send(request).timeout(timeout);

  @override
  void close() => inner.close();
}
