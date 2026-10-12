import 'package:equatable/equatable.dart';

import 'day_prayers.dart';
import 'hijri_date.dart';
import 'reading_progress.dart';
import 'tawaf_session.dart';

/// Everything the Spiritual Dashboard shows, in one immutable value.
class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.city,
    required this.hijri,
    required this.prayers,
    required this.reading,
    this.activeRite,
  });

  final String city;
  final HijriDate hijri;
  final DayPrayers prayers;
  final ReadingProgress reading;

  /// The in-progress Tawaf / Sa'i session, or null when no rite is active.
  final TawafSession? activeRite;

  @override
  List<Object?> get props => [city, hijri, prayers, reading, activeRite];
}
