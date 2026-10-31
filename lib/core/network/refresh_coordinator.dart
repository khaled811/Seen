import 'access_token_store.dart';
import 'session_remote_data_source.dart';

enum RefreshStatus {
  /// A new access token is now in the [AccessTokenStore].
  refreshed,

  /// The server ended the session (`session_expired`, `no_refresh_session`, ...).
  /// The token store was cleared; the person must sign in again.
  sessionEnded,

  /// Nothing is known to have changed (timeout, no network, rate limit, the
  /// session was ended locally meanwhile). Never retried automatically: a
  /// refresh rotates the cookie and replaying a rotated one ends the session.
  failed,
}

/// Runs `refresh` for everyone who needs it.
///
/// While a refresh is in flight every other caller awaits that same call, so N
/// requests that fail together cause exactly one rotation.
class RefreshCoordinator {
  RefreshCoordinator({required AccessTokenStore tokens, required SessionRemoteDataSource remote})
      : _tokens = tokens,
        _remote = remote;

  final AccessTokenStore _tokens;
  final SessionRemoteDataSource _remote;

  Future<RefreshStatus>? _inFlight;

  /// Completes when no refresh is running (immediately if none is).
  Future<void> get idle async {
    final running = _inFlight;
    if (running != null) await running;
  }

  Future<RefreshStatus> refresh() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<RefreshStatus> _run() async {
    final generation = _tokens.generation;
    final RefreshResponse response;
    try {
      response = await _remote.refresh();
    } catch (_) {
      return RefreshStatus.failed;
    }
    // A sign-out (or a new sign-in) happened while the call was in the air:
    // its answer belongs to a session that no longer exists.
    if (_tokens.generation != generation) return RefreshStatus.failed;
    switch (response) {
      case RefreshSucceeded(:final accessToken):
        _tokens.set(accessToken);
        return RefreshStatus.refreshed;
      case RefreshRejected():
        _tokens.clear();
        return RefreshStatus.sessionEnded;
      case RefreshUnavailable():
        return RefreshStatus.failed;
    }
  }
}
