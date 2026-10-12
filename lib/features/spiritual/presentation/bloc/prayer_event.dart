import 'package:equatable/equatable.dart';

import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/prayer_preferences.dart';

enum PrayerView { day, month }

sealed class PrayerEvent extends Equatable {
  const PrayerEvent();

  @override
  List<Object?> get props => [];
}

class PrayerStarted extends PrayerEvent {
  const PrayerStarted();
}

/// Clock tick (every 30 s): moves the sun and the countdowns.
class PrayerTicked extends PrayerEvent {
  const PrayerTicked();
}

/// Previous (-1) / next (+1): one day, or one Hijri month in month view.
class PrayerDateShifted extends PrayerEvent {
  const PrayerDateShifted(this.step);

  final int step;

  @override
  List<Object?> get props => [step];
}

class PrayerViewChanged extends PrayerEvent {
  const PrayerViewChanged(this.view);

  final PrayerView view;

  @override
  List<Object?> get props => [view];
}

class PrayerMarkerSelected extends PrayerEvent {
  const PrayerMarkerSelected(this.id);

  final PrayerId id;

  @override
  List<Object?> get props => [id];
}

/// Cycle one prayer's alert: sound -> vibrate -> silent.
class PrayerAlertCycled extends PrayerEvent {
  const PrayerAlertCycled(this.id);

  final PrayerId id;

  @override
  List<Object?> get props => [id];
}

/// Method, madhab or pre-alert changed in settings.
class PrayerSettingsChanged extends PrayerEvent {
  const PrayerSettingsChanged(this.preferences);

  final PrayerPreferences preferences;

  @override
  List<Object?> get props => [preferences];
}

/// Pick a city by hand, or null to use the GPS again (asks for permission).
class PrayerCitySelected extends PrayerEvent {
  const PrayerCitySelected(this.cityId);

  final String? cityId;

  @override
  List<Object?> get props => [cityId];
}

/// Show the notification permission prompt.
class PrayerNotificationsRequested extends PrayerEvent {
  const PrayerNotificationsRequested();
}

/// Open the system settings (after a permanent location denial).
class PrayerOpenSettingsRequested extends PrayerEvent {
  const PrayerOpenSettingsRequested();
}
