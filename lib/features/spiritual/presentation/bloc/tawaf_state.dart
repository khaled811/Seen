import 'package:equatable/equatable.dart';

import '../../domain/entities/dua.dart';
import '../../domain/entities/tawaf_session.dart';

/// What the last user action did; drives haptics, announcements and the
/// status line.
enum TawafAction {
  /// Fresh start or restored session: nothing just happened.
  none,
  lapRecorded,
  completed,
  undone,
  modeChanged,
}

sealed class TawafState extends Equatable {
  const TawafState();

  @override
  List<Object?> get props => [];
}

class TawafLoading extends TawafState {
  const TawafLoading();
}

class TawafReady extends TawafState {
  const TawafReady({
    required this.session,
    this.dua,
    this.action = TawafAction.none,
    this.statusLap = 0,
    this.actionSeq = 0,
    this.saveFailed = false,
  });

  final TawafSession session;

  /// The dua for the current rite, or null when none is available (e.g. an
  /// unreviewed dua in a release build).
  final Dua? dua;
  final TawafAction action;

  /// Lap number the status line refers to ("تم تسجيل الشوط ٢").
  final int statusLap;

  /// Increments on every user action, so identical consecutive actions still
  /// produce a distinct state (flash, haptic, announcement).
  final int actionSeq;

  /// The session could not be written to disk after this action. Progress is
  /// kept in memory; the UI warns once.
  final bool saveFailed;

  TawafReady copyWith({
    TawafSession? session,
    Dua? dua,
    TawafAction? action,
    int? statusLap,
    int? actionSeq,
    bool? saveFailed,
  }) =>
      TawafReady(
        session: session ?? this.session,
        dua: dua ?? this.dua,
        action: action ?? this.action,
        statusLap: statusLap ?? this.statusLap,
        actionSeq: actionSeq ?? this.actionSeq,
        saveFailed: saveFailed ?? this.saveFailed,
      );

  @override
  List<Object?> get props =>
      [session, dua, action, statusLap, actionSeq, saveFailed];
}

/// The rite was ended; the screen should close.
class TawafEnded extends TawafState {
  const TawafEnded();
}
