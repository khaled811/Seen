import 'package:equatable/equatable.dart';

import 'prayer_id.dart';

/// One notification to be shown at [time].
class Reminder extends Equatable {
  const Reminder({
    required this.id,
    required this.prayer,
    required this.time,
    required this.mode,
    required this.title,
    required this.body,
    this.isPreAlert = false,
  });

  /// Stable id (date + prayer + pre-alert flag) so rescheduling the same
  /// reminder replaces rather than duplicates it.
  final int id;
  final PrayerId prayer;
  final DateTime time;

  /// [AlertMode.sound] or [AlertMode.vibrate] (silent prayers get no reminder).
  final AlertMode mode;
  final String title;
  final String body;
  final bool isPreAlert;

  @override
  List<Object?> get props => [id, prayer, time, mode, title, body, isPreAlert];
}
