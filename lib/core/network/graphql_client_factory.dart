import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_error_codes.dart';
import 'auth_session_controller.dart';
import 'network_config.dart';

/// Builds and owns the app's single [GraphQLClient].
///
/// Link chain (outermost first):
/// [ErrorLink] observes GraphQL errors and reports a dead session or a missing
/// permission to [AuthSessionController] (without acting on them itself) ->
/// [HttpLink] (terminal) sends the request through the supplied [http.Client],
/// which in the app is the shared Dio client (`DioHttpClient`): that is where
/// the access token is attached, the refresh cookie is kept and an expired
/// token is refreshed. The token is therefore not handled in this class.
///
/// Caching: nothing is ever served from the cache. Every operation is
/// `noCache` by default (the library default for queries is `cacheFirst`,
/// which could show one user's data to the next), and [clearCache] empties what
/// the explicit `networkOnly` operations stored. Transport failures (HTTP
/// 401/403 from a proxy, timeouts) do not end the session; only the documented
/// GraphQL codes do.
class GraphQLClientFactory {
  GraphQLClientFactory({
    required this.authSessionController,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  final AuthSessionController authSessionController;
  final http.Client _httpClient;

  GraphQLClient? _client;

  /// The shared client, built lazily on first access.
  GraphQLClient get client => _client ??= _build();

  GraphQLClient _build() {
    final httpLink = HttpLink(NetworkConfig.graphqlEndpoint, httpClient: _httpClient);

    final errorLink = ErrorLink(
      onGraphQLError: (request, forward, response) {
        for (final error in response.errors ?? const <GraphQLError>[]) {
          switch (error.extensions?['code']) {
            case ApiErrorCodes.notAuthenticated:
            case ApiErrorCodes.sessionExpired:
            case ApiErrorCodes.noRefreshSession:
              authSessionController.notifyUnauthenticated();
            case ApiErrorCodes.permissionDenied:
              authSessionController.notifyForbidden();
          }
        }
        // Returning null lets the original response propagate — the caller
        // (`GraphQLService`) still needs it to build an `Either<Failure, T>`.
        return null;
      },
    );

    final noCache = Policies(fetch: FetchPolicy.noCache);
    return GraphQLClient(
      link: Link.from([errorLink, httpLink]),
      cache: GraphQLCache(),
      defaultPolicies: DefaultPolicies(query: noCache, watchQuery: noCache, mutate: noCache, watchMutation: noCache),
    );
  }

  /// Forgets everything the cache stored (sign-out, session expiry).
  Future<void> clearCache() async {
    final client = _client;
    if (client == null) return;
    await client.resetStore(refetchQueries: false);
  }

  /// Closes the underlying HTTP client. Call exactly once, from the
  /// composition root, on app/DI teardown — never mid-app-lifetime.
  Future<void> dispose() => _client?.link.dispose() ?? Future<void>.value();
}
