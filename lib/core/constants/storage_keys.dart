/// Shared `flutter_secure_storage` key names.
///
/// Centralised so core infra (e.g. the network layer, reading the token) and
/// feature code (e.g. auth, writing the token on login) agree on where a
/// value lives without importing each other's internals.
abstract final class StorageKeys {
  static const String authToken = 'auth_token';

  /// JSON blob: `{userId, userType, position, branchId, permissionCodes}`.
  /// A cache for instant session restore only — the backend remains the
  /// source of truth and re-validates every permission server-side.
  static const String sessionUser = 'session_user';
}
