import '../../core/arabic_digits.dart';
import '../../domain/entities/rite_mode.dart';
import '../../domain/entities/tawaf_session.dart';
import '../bloc/tawaf_state.dart';
import '../spiritual_strings.dart';

/// All Arabic copy that depends on the session (docs/03 §2).
abstract final class TawafTexts {
  static String title(RiteMode mode) => mode == RiteMode.tawaf
      ? SpiritualStrings.tawafOfUmrah
      : SpiritualStrings.saiOfUmrah;

  static String riteName(RiteMode mode) =>
      mode == RiteMode.tawaf ? 'الطواف' : 'السعي';

  static String duaLabel(RiteMode mode) => mode == RiteMode.tawaf
      ? SpiritualStrings.duaTawafLabel
      : SpiritualStrings.duaSaiLabel;

  static String doneLabel(RiteMode mode) => mode == RiteMode.tawaf
      ? SpiritualStrings.tawafDone
      : SpiritualStrings.saiDone;

  /// One-line instruction under the ring.
  static String guide(TawafSession s) {
    if (s.done) {
      return s.mode == RiteMode.tawaf
          ? SpiritualStrings.acceptedTawaf
          : SpiritualStrings.acceptedSai;
    }
    if (s.mode == RiteMode.tawaf) {
      return s.currentLap == 1
          ? SpiritualStrings.guideTawafFirst
          : SpiritualStrings.guideTawaf;
    }
    return s.currentLap.isOdd
        ? SpiritualStrings.guideSaiOdd
        : SpiritualStrings.guideSaiEven;
  }

  /// Status pill text.
  static String status(TawafReady r) {
    final n = toArabicDigits(r.statusLap);
    return switch (r.action) {
      TawafAction.lapRecorded || TawafAction.completed => 'تم تسجيل الشوط $n',
      TawafAction.undone => 'أُلغي تسجيل الشوط $n',
      TawafAction.modeChanged => 'بداية ${riteName(r.session.mode)}',
      TawafAction.none => r.statusLap > 0
          ? 'تم تسجيل الشوط $n'
          : 'بداية ${riteName(r.session.mode)}',
    };
  }

  static String primaryLabel(TawafSession s) {
    if (s.done) {
      return s.mode == RiteMode.tawaf
          ? SpiritualStrings.btnToSai
          : SpiritualStrings.btnDone;
    }
    return s.isLastLap ? SpiritualStrings.btnLast : SpiritualStrings.btnNext;
  }

  static String primaryHint(TawafSession s) {
    if (s.done) {
      return s.mode == RiteMode.tawaf
          ? SpiritualStrings.hintToSai
          : SpiritualStrings.hintDone;
    }
    return s.mode == RiteMode.tawaf
        ? SpiritualStrings.hintTawaf
        : SpiritualStrings.hintSai;
  }

  /// Screen-reader announcement after a recorded lap.
  static String lapAnnouncement(TawafReady r) => r.session.done
      ? guide(r.session)
      : 'تم تسجيل الشوط ${toArabicDigits(r.statusLap)}، '
          'الشوط الحالي ${toArabicDigits(r.session.currentLap)}';

  static String lapProgress(TawafSession s) => toArabicDigits(
        'الشوط ${s.currentLap} من ${TawafSession.totalLaps}',
      );
}
