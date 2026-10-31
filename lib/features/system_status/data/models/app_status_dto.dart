import '../../domain/entities/app_status.dart';

/// NOTE: the contract has no app-status operation (DECISIONS P-06); this shape is only used by the unavailable state.
class AppStatusDto {
  const AppStatusDto({
    required this.maintenance,
    this.maintenanceEta,
    this.minimumVersion,
    this.latestVersion,
    this.storeUrl,
    this.updateNote,
  });

  factory AppStatusDto.fromJson(Map<String, dynamic> json) {
    final m = json['maintenance'];
    final maintenance =
        m is Map<String, dynamic> ? m : const <String, dynamic>{};
    return AppStatusDto(
      maintenance: maintenance['active'] == true,
      maintenanceEta: DateTime.tryParse(maintenance['etaAt'] as String? ?? ''),
      minimumVersion: json['minimumVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      storeUrl: json['storeUrl'] as String?,
      updateNote: json['updateNote'] as String?,
    );
  }

  final bool maintenance;
  final DateTime? maintenanceEta;
  final String? minimumVersion;
  final String? latestVersion;
  final String? storeUrl;
  final String? updateNote;

  AppStatus toEntity() => AppStatus(
        maintenance: maintenance,
        maintenanceEta: maintenanceEta?.toLocal(),
        minimumVersion: minimumVersion,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
        updateNote: updateNote,
      );
}
