/// Network configuration for the GraphQL client.
///
/// Override at build/run time, e.g.:
/// `flutter run --dart-define=GRAPHQL_ENDPOINT=https://staging.seenbooking.example.com/graphql/`
abstract final class NetworkConfig {
  // TODO: replace with the real Seen Booking backend endpoint. Kept as a
  // placeholder so this compiles and runs against a mock/local server until
  // the production value is provided.
  static const String graphqlEndpoint = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
    defaultValue: 'https://api.seenbooking.example.com/graphql/',
  );

  /// Applied to every request via a wrapped [http.Client] — `HttpLink` has
  /// no built-in timeout.
  static const Duration requestTimeout = Duration(seconds: 20);
}
