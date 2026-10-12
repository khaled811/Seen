/// The seven timed moments of a day, in chronological order. The first, third
/// to sixth are the five obligatory prayers (adhan); sunrise and midnight are
/// reminders only.
enum PrayerId {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
  midnight;

  /// One of the five obligatory prayers.
  bool get isPrayer => this != sunrise && this != midnight;

  /// Arabic display name.
  String get nameAr => switch (this) {
        fajr => 'الفجر',
        sunrise => 'الشروق',
        dhuhr => 'الظهر',
        asr => 'العصر',
        maghrib => 'المغرب',
        isha => 'العشاء',
        midnight => 'منتصف الليل',
      };
}

/// How a prayer reminds the user (docs/03 §5): the full adhan, vibration
/// only, or nothing.
enum AlertMode {
  sound,
  vibrate,
  silent;

  /// sound -> vibrate -> silent -> sound.
  AlertMode get next => AlertMode.values[(index + 1) % AlertMode.values.length];
}
