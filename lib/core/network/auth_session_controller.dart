import 'dart:async';

/// Session-affecting events raised by the network layer when the backend
/// rejects a request due to authentication or authorization.
enum AuthSessionEvent {
  /// 401 — the token is missing, invalid, or expired. The app should clear
  /// the session and route to sign-in.
  unauthenticated,

  /// 403 — the session is valid but lacks the required permission.
  forbidden,
}

/// Broadcasts [AuthSessionEvent]s from the network layer to whoever is
/// listening (typically a root-level `BlocListener`), without the network
/// layer depending on navigation or any UI code.
///
/// Lifecycle: constructed once alongside [GraphQLClientFactory] in the
/// composition root (DI setup) and lives for the app's lifetime. [dispose]
/// exists for tests/hot-restart scenarios that recreate the DI graph — do
/// not call it while the app is still running with listeners attached.
class AuthSessionController {
  final _controller = StreamController<AuthSessionEvent>.broadcast();

  Stream<AuthSessionEvent> get events => _controller.stream;

  void notifyUnauthenticated() => _add(AuthSessionEvent.unauthenticated);

  void notifyForbidden() => _add(AuthSessionEvent.forbidden);

  void _add(AuthSessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
