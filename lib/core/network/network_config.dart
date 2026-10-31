import 'package:flutter/foundation.dart' show kDebugMode;

/// Network configuration for the GraphQL client.
///
/// The app talks to [defaultEndpoint] unless a build overrides it:
/// `flutter build apk --dart-define=GRAPHQL_ENDPOINT=https://<host>/graphql/`
///
/// [validate] (called from `main`) refuses to start a non-debug build whose
/// endpoint is not an `https` URL with a real host.
abstract final class NetworkConfig {
  static const String _configuredEndpoint = String.fromEnvironment('GRAPHQL_ENDPOINT');

  /// The backend host given by the platform team (the backend developer's answer,
  /// 2026-10-20). Whether it is staging or production is not stated.
  static const String defaultEndpoint = 'https://b2b.seenbooking.com/graphql/';

  /// The endpoint the client talks to: the build define when given, else [defaultEndpoint].
  static String get graphqlEndpoint => _configuredEndpoint.isNotEmpty ? _configuredEndpoint : defaultEndpoint;

  /// Throws [StateError] when a non-debug build is mis-configured. Returns
  /// normally in debug builds.
  static void validate() {
    if (kDebugMode) return;
    final problem = endpointProblem(graphqlEndpoint);
    if (problem != null) throw StateError(problem);
  }

  /// Why [endpoint] is unusable in a non-debug build, or null when it is fine.
  /// Pure, so it is unit-testable without a release build.
  static String? endpointProblem(String endpoint) {
    if (endpoint.isEmpty) {
      return 'GRAPHQL_ENDPOINT is not set. Build with '
          '--dart-define=GRAPHQL_ENDPOINT=https://<host>/graphql/';
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'GRAPHQL_ENDPOINT must be an https URL with a host.';
    }
    if (uri.host.endsWith('.example.com') || uri.host.endsWith('.invalid')) {
      return 'GRAPHQL_ENDPOINT points at a placeholder host.';
    }
    return null;
  }

  /// Applied to every request via a wrapped [http.Client] — `HttpLink` has
  /// no built-in timeout.
  static const Duration requestTimeout = Duration(seconds: 20);
}
