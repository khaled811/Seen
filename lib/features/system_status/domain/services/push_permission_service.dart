/// Where the device's notification permission stands (Figma NOTIF-03).
enum PushPermissionStatus {
  /// Never asked: the system prompt can still be shown.
  notDetermined,
  granted,

  /// Asked and refused: only the device settings can change it.
  denied,

  /// This device or build cannot show notifications (or the check failed).
  unavailable,
}

/// The notification permission and the "did we already offer it" memory. Pure Dart.
abstract interface class PushPermissionService {
  Future<PushPermissionStatus> status();

  /// Shows the system prompt (once; afterwards it answers [PushPermissionStatus.denied]
  /// without a prompt).
  Future<PushPermissionStatus> request();

  /// Opens the app's page in the device settings. `false` = this device cannot do it
  /// from here (the user must open the settings themselves).
  Future<bool> openSettings();

  /// The pre-permission screen is offered once per install, not on every start.
  Future<bool> promptShown();

  Future<void> markPromptShown();
}
