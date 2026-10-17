import 'package:equatable/equatable.dart';

/// What the server says about the app right now (Figma SYS-04 / SYS-05).
/// Pure Dart.
class AppStatus extends Equatable {
  const AppStatus({
    this.maintenance = false,
    this.maintenanceEta,
    this.minimumVersion,
    this.latestVersion,
    this.storeUrl,
    this.updateNote,
  });

  /// Nothing to report: the app runs normally.
  static const ok = AppStatus();

  final bool maintenance;

  /// When the server expects to be back; null when it does not say.
  final DateTime? maintenanceEta;

  /// Versions below this must update before use (hard update).
  final String? minimumVersion;

  /// The newest published version (soft update when the app is older).
  final String? latestVersion;

  /// Where the store listing is for this platform.
  final String? storeUrl;

  /// One line about what the newest version brings ("wallet improvements").
  final String? updateNote;

  @override
  List<Object?> get props => [
        maintenance,
        maintenanceEta,
        minimumVersion,
        latestVersion,
        storeUrl,
        updateNote
      ];
}
