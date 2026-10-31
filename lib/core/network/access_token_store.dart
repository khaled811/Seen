/// The access token, in memory only (never written to the device).
///
/// [generation] changes on every [set] and [clear]. A request remembers the
/// generation it was sent with; when it comes back `not_authenticated` the
/// generation says whether a refresh or a sign-out already happened meanwhile,
/// so concurrent failures share one refresh and a request from a finished
/// session is never revived.
class AccessTokenStore {
  AccessTokenStore({DateTime Function() clock = DateTime.now}) : _clock = clock;

  /// The token lives 15 minutes; refreshing a little earlier avoids most
  /// `not_authenticated` round trips (contract section 3.4).
  static const Duration staleAfter = Duration(minutes: 13);

  final DateTime Function() _clock;

  String? _token;
  DateTime? _receivedAt;
  int _generation = 0;

  String? get token => _token;

  bool get hasToken => _token != null;

  int get generation => _generation;

  /// True when a token is held and it is old enough to refresh before use.
  bool get isStale {
    final received = _receivedAt;
    return _token != null && received != null && _clock().difference(received) >= staleAfter;
  }

  void set(String token) {
    _token = token;
    _receivedAt = _clock();
    _generation++;
  }

  void clear() {
    _token = null;
    _receivedAt = null;
    _generation++;
  }
}
