import '../entities/tasbeeh.dart';

/// The tasbeeh's rules, free of UI and storage so they can be tested to the
/// last count.
abstract final class TasbeehMath {
  /// Open mode shows progress within each block of this many counts.
  static const openBlock = 100;

  /// "yyyy-MM-dd" in the device's local calendar.
  static String dayKey(DateTime now) {
    final l = now.toLocal();
    final m = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    return '${l.year}-$m-$d';
  }

  /// Starts a new day: yesterday's tallies are dropped at local midnight; the
  /// count in hand is kept, since a round may straddle midnight.
  static TasbeehProgress rollDay(TasbeehProgress p, DateTime now) {
    final key = dayKey(now);
    if (p.day == key) return p;
    return p.copyWith(day: key, daily: const {});
  }

  /// One tap. After a completed round the next tap starts the new one at 1
  /// (never at 0, so a tap is never lost).
  static TasbeehProgress tap(TasbeehProgress p, DateTime now) {
    final r = rollDay(p, now);
    final count = r.complete ? 1 : r.count + 1;
    final done = !r.target.isOpen && count >= r.target.value;
    final today = r.today;
    return r.copyWith(
      count: count,
      complete: done,
      daily: {
        ...r.daily,
        r.dhikrId: DhikrDay(
          total: today.total + 1,
          rounds: done ? today.rounds + 1 : today.rounds,
        ),
      },
    );
  }

  /// Back to zero; the day's tallies stay.
  static TasbeehProgress reset(TasbeehProgress p) =>
      p.copyWith(count: 0, complete: false);

  /// Switching to another dhikr starts from zero; picking the current one
  /// changes nothing.
  static TasbeehProgress selectDhikr(
    TasbeehProgress p,
    String id,
    DateTime now,
  ) {
    final r = rollDay(p, now);
    if (r.dhikrId == id) return r;
    return r.copyWith(dhikrId: id, count: 0, complete: false);
  }

  /// A target the count has already reached completes the round at once.
  static TasbeehProgress selectTarget(TasbeehProgress p, TasbeehTarget t) =>
      p.copyWith(
        target: t,
        complete: !t.isOpen && p.count >= t.value,
      );

  /// 0..1 for the ring: progress to the target, or within the current block
  /// of [openBlock] when open.
  static double ringValue(TasbeehProgress p) {
    if (p.target.isOpen) return (p.count % openBlock) / openBlock;
    return (p.count / p.target.value).clamp(0.0, 1.0);
  }
}
