import 'package:equatable/equatable.dart';

import 'calc_settings.dart';
import 'prayer_id.dart';

/// A GPS position remembered from an earlier fix.
class SavedFix extends Equatable {
  const SavedFix({
    required this.latitude,
    required this.longitude,
    required this.at,
  });

  final double latitude;
  final double longitude;
  final DateTime at;

  @override
  List<Object?> get props => [latitude, longitude, at];
}

/// Everything about prayer times that survives an app kill.
class PrayerPreferences extends Equatable {
  const PrayerPreferences({
    this.alertModes = defaultModes,
    this.method = CalcMethod.ummAlQura,
    this.madhab = AsrMadhab.shafi,
    this.preAlertMinutes = 0,
    this.cityId,
    this.lastFix,
    this.locationPrompted = false,
    this.notificationsPrompted = false,
  });

  /// The five prayers sound the adhan; sunrise and midnight stay silent until
  /// the user opts in.
  static const defaultModes = <PrayerId, AlertMode>{
    PrayerId.fajr: AlertMode.sound,
    PrayerId.sunrise: AlertMode.silent,
    PrayerId.dhuhr: AlertMode.sound,
    PrayerId.asr: AlertMode.sound,
    PrayerId.maghrib: AlertMode.sound,
    PrayerId.isha: AlertMode.sound,
    PrayerId.midnight: AlertMode.silent,
  };

  /// Minutes of notice before each prayer; 0 = none.
  static const preAlertChoices = [0, 5, 10, 15];

  final Map<PrayerId, AlertMode> alertModes;
  final CalcMethod method;
  final AsrMadhab madhab;
  final int preAlertMinutes;

  /// A manually chosen [SaudiCities] id; null = use GPS.
  final String? cityId;
  final SavedFix? lastFix;
  final bool locationPrompted;
  final bool notificationsPrompted;

  AlertMode modeOf(PrayerId id) => alertModes[id] ?? AlertMode.silent;

  PrayerPreferences withMode(PrayerId id, AlertMode mode) => copyWith(
        alertModes: {...alertModes, id: mode},
      );

  PrayerPreferences copyWith({
    Map<PrayerId, AlertMode>? alertModes,
    CalcMethod? method,
    AsrMadhab? madhab,
    int? preAlertMinutes,
    String? cityId,
    bool clearCity = false,
    SavedFix? lastFix,
    bool? locationPrompted,
    bool? notificationsPrompted,
  }) =>
      PrayerPreferences(
        alertModes: alertModes ?? this.alertModes,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        preAlertMinutes: preAlertMinutes ?? this.preAlertMinutes,
        cityId: clearCity ? null : (cityId ?? this.cityId),
        lastFix: lastFix ?? this.lastFix,
        locationPrompted: locationPrompted ?? this.locationPrompted,
        notificationsPrompted: notificationsPrompted ?? this.notificationsPrompted,
      );

  @override
  List<Object?> get props => [
        alertModes.entries.map((e) => '${e.key.name}:${e.value.name}').toList()
          ..sort(),
        method,
        madhab,
        preAlertMinutes,
        cityId,
        lastFix,
        locationPrompted,
        notificationsPrompted,
      ];
}
