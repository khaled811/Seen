import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';

import 'access_token_store.dart';
import 'refresh_coordinator.dart';
import 'session_remote_data_source.dart';

/// Starts, restores and ends the authenticated session on the transport side.
///
/// The authentication feature owns *who* is signed in (the `me` data, the
/// Bloc state); this class owns the credentials and everything that must be
/// forgotten when the session ends.
class SessionManager {
  SessionManager({
    required AccessTokenStore tokens,
    required RefreshCoordinator coordinator,
    required SessionRemoteDataSource remote,
    required CookieJar cookieJar,
    required Future<void> Function() clearHttpCache,
    List<Future<void> Function()> cleanups = const [],
    Duration idleWait = const Duration(seconds: 3),
    Duration serverLogoutTimeout = const Duration(seconds: 3),
  })  : _tokens = tokens,
        _coordinator = coordinator,
        _remote = remote,
        _cookieJar = cookieJar,
        _clearHttpCache = clearHttpCache,
        _cleanups = cleanups,
        _idleWait = idleWait,
        _serverLogoutTimeout = serverLogoutTimeout;

  final AccessTokenStore _tokens;
  final RefreshCoordinator _coordinator;
  final SessionRemoteDataSource _remote;
  final CookieJar _cookieJar;
  final Future<void> Function() _clearHttpCache;
  final List<Future<void> Function()> _cleanups;
  final Duration _idleWait;
  final Duration _serverLogoutTimeout;

  AccessTokenStore get tokens => _tokens;

  /// A sign-in just produced [accessToken]; the matching cookie is already in
  /// the jar (the cookie manager stored it with the response).
  void startSession(String accessToken) => _tokens.set(accessToken);

  /// Launch-time restore, step one: turns the stored refresh cookie into an
  /// access token. Shares any refresh already running. The caller then calls
  /// `me` and only then shows the signed-in app.
  Future<RefreshStatus> restoreAccessToken() => _coordinator.refresh();

  /// Ends the session and forgets everything tied to it. Every step runs even
  /// if an earlier one fails, including when the server cannot be reached.
  ///
  /// Order: drop the token first (so a request still in flight cannot revive
  /// the session), let a refresh that is already running finish (it rotates the
  /// cookie, which the server-side logout needs), ask the server to end the
  /// session, then wipe the cookie jar, the GraphQL cache and per-user data.
  Future<void> endSession() async {
    _tokens.clear();
    try {
      await _coordinator.idle.timeout(_idleWait);
    } catch (_) {
      // Do not let a hung refresh block signing out.
    }
    try {
      await _remote.logout().timeout(_serverLogoutTimeout);
    } catch (_) {
      // Best effort: local cleanup below is what protects the device.
    }
    await _safely(_cookieJar.deleteAll);
    await _safely(_clearHttpCache);
    for (final cleanup in _cleanups) {
      await _safely(cleanup);
    }
  }

  static Future<void> _safely(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // One failing step must not stop the others.
    }
  }
}
