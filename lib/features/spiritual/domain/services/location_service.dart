import '../entities/location_fix.dart';

/// Device position, abstracted from the plugin.
abstract interface class LocationService {
  /// Current position. With [askPermission] false, an undecided permission
  /// is reported as [LocationDenied] without showing a system dialog.
  Future<LocationFix> currentFix({required bool askPermission});

  /// Opens the system settings page for this app (after a permanent denial).
  Future<void> openSettings();
}
