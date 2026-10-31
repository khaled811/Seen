import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/network_config.dart';

void main() {
  group('NetworkConfig.endpointProblem (release-build rules)', () {
    test('rejects an empty endpoint', () {
      expect(NetworkConfig.endpointProblem(''), contains('GRAPHQL_ENDPOINT is not set'));
    });

    test('rejects non-https and malformed endpoints', () {
      expect(NetworkConfig.endpointProblem('http://api.real-host.net/graphql/'), contains('https'));
      expect(NetworkConfig.endpointProblem('not a url'), contains('https'));
      expect(NetworkConfig.endpointProblem('https:///graphql/'), contains('https'));
    });

    test('rejects the placeholder host', () {
      expect(
        NetworkConfig.endpointProblem('https://api.seenbooking.example.com/graphql/'),
        contains('placeholder'),
      );
    });

    test('accepts a real https endpoint', () {
      expect(NetworkConfig.endpointProblem('https://api.real-host.net/graphql/'), isNull);
    });
  });

  test('validate() is a no-op outside release builds', () {
    expect(NetworkConfig.validate, returnsNormally);
  });

  test('a debug build still resolves an endpoint with no define', () {
    expect(NetworkConfig.graphqlEndpoint, isNotEmpty);
  });

  test('the default endpoint is the backend host and passes the release rules', () {
    expect(NetworkConfig.defaultEndpoint, 'https://b2b.seenbooking.com/graphql/');
    expect(NetworkConfig.endpointProblem(NetworkConfig.defaultEndpoint), isNull);
    expect(NetworkConfig.graphqlEndpoint, NetworkConfig.defaultEndpoint); // no define in tests
  });
}
