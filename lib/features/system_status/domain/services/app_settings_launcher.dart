/// Opens this app's page in the device settings. `false` = the device cannot do it from
/// here (the user must open the settings themselves).
abstract interface class AppSettingsLauncher {
  Future<bool> open();
}
