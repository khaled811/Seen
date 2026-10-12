import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/rite_mode.dart';
import '../../domain/entities/tawaf_session.dart';
import '../../domain/usecases/end_session_usecase.dart';
import '../../domain/usecases/get_duas_usecase.dart';
import '../../domain/usecases/record_lap_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import '../../domain/usecases/start_session_usecase.dart';
import '../../domain/usecases/undo_lap_usecase.dart';
import 'tawaf_event.dart';
import 'tawaf_state.dart';

/// Field companion for Tawaf and Sa'i.
///
/// Safety properties:
///  * every transition is persisted before it is announced; if the disk write
///    fails the progress is still kept in memory and `saveFailed` is raised;
///  * the lap button is `droppable` (no queued double taps) and the use case
///    additionally rejects taps within [RecordLapUseCase.debounce] of the
///    previous lap.
class TawafBloc extends Bloc<TawafEvent, TawafState> {
  TawafBloc({
    required RestoreSessionUseCase restoreSession,
    required StartSessionUseCase startSession,
    required RecordLapUseCase recordLap,
    required UndoLapUseCase undoLap,
    required EndSessionUseCase endSession,
    required GetDuasUseCase getDuas,
    DateTime Function()? clock,
  })  : _restoreSession = restoreSession,
        _startSession = startSession,
        _recordLap = recordLap,
        _undoLap = undoLap,
        _endSession = endSession,
        _getDuas = getDuas,
        _clock = clock ?? DateTime.now,
        super(const TawafLoading()) {
    on<TawafStarted>(_onStarted);
    on<TawafPrimaryPressed>(_onPrimary, transformer: droppable());
    on<TawafUndoRequested>(_onUndo, transformer: droppable());
    on<TawafModeSelected>(_onMode, transformer: droppable());
    on<TawafEndRequested>(_onEnd, transformer: droppable());
  }

  /// Dua ids in `duas.json` for each rite.
  static const duaIds = {
    RiteMode.tawaf: 'rukn',
    RiteMode.sai: 'safa-marwa',
  };

  final RestoreSessionUseCase _restoreSession;
  final StartSessionUseCase _startSession;
  final RecordLapUseCase _recordLap;
  final UndoLapUseCase _undoLap;
  final EndSessionUseCase _endSession;
  final GetDuasUseCase _getDuas;
  final DateTime Function() _clock;

  Map<String, Dua> _duas = const {};

  TawafReady? get _ready => state is TawafReady ? state as TawafReady : null;

  Dua? _duaFor(RiteMode mode) => _duas[duaIds[mode]];

  Future<void> _onStarted(TawafStarted event, Emitter<TawafState> emit) async {
    final duas = await _getDuas();
    _duas = duas.fold((_) => const {}, (list) => {for (final d in list) d.id: d});

    var saveFailed = false;
    final restored = await _restoreSession();
    final TawafSession? existing = restored.fold((_) {
      saveFailed = true; // unreadable store: start fresh, warn
      return null;
    }, (s) => s);

    final TawafSession session;
    if (existing != null) {
      session = existing;
    } else {
      final started = await _startSession(RiteMode.tawaf, now: _clock());
      session = started.fold((_) {
        saveFailed = true;
        return TawafSession.start(RiteMode.tawaf, _clock());
      }, (s) => s);
    }
    if (isClosed) return;
    emit(TawafReady(
      session: session,
      dua: _duaFor(session.mode),
      statusLap: session.completedLaps,
      saveFailed: saveFailed,
    ));
  }

  Future<void> _onPrimary(
    TawafPrimaryPressed event,
    Emitter<TawafState> emit,
  ) async {
    final current = _ready;
    if (current == null) return;
    final s = current.session;

    if (s.done) {
      if (s.mode == RiteMode.tawaf) {
        await _switchTo(RiteMode.sai, current, emit);
      } else {
        await _end(current, emit);
      }
      return;
    }

    final now = _clock();
    final result = await _recordLap(s, now: now);
    TawafSession? next;
    var saveFailed = false;
    result.fold(
      (failure) {
        if (failure is ValidationFailure) return; // debounced: ignore the tap
        next = s.recordLap(now);
        saveFailed = true;
      },
      (session) => next = session,
    );
    final recorded = next;
    if (recorded == null || isClosed) return;
    emit(current.copyWith(
      session: recorded,
      action: recorded.done ? TawafAction.completed : TawafAction.lapRecorded,
      statusLap: s.currentLap,
      actionSeq: current.actionSeq + 1,
      saveFailed: saveFailed,
    ));
  }

  Future<void> _onUndo(
    TawafUndoRequested event,
    Emitter<TawafState> emit,
  ) async {
    final current = _ready;
    if (current == null || !current.session.canUndo) return;
    final s = current.session;
    final result = await _undoLap(s);
    var saveFailed = false;
    final next = result.fold((_) {
      saveFailed = true;
      return s.undoLap();
    }, (session) => session);
    if (isClosed) return;
    emit(current.copyWith(
      session: next,
      action: TawafAction.undone,
      statusLap: next.currentLap,
      actionSeq: current.actionSeq + 1,
      saveFailed: saveFailed,
    ));
  }

  Future<void> _onMode(
    TawafModeSelected event,
    Emitter<TawafState> emit,
  ) async {
    final current = _ready;
    if (current == null || current.session.mode == event.mode) return;
    await _switchTo(event.mode, current, emit);
  }

  Future<void> _switchTo(
    RiteMode mode,
    TawafReady current,
    Emitter<TawafState> emit,
  ) async {
    final result = await _startSession(mode, now: _clock());
    var saveFailed = false;
    final session = result.fold((_) {
      saveFailed = true;
      return TawafSession.start(mode, _clock());
    }, (s) => s);
    if (isClosed) return;
    emit(TawafReady(
      session: session,
      dua: _duaFor(mode),
      action: TawafAction.modeChanged,
      statusLap: 0,
      actionSeq: current.actionSeq + 1,
      saveFailed: saveFailed,
    ));
  }

  Future<void> _onEnd(
    TawafEndRequested event,
    Emitter<TawafState> emit,
  ) async {
    final current = _ready;
    if (current == null) return;
    await _end(current, emit);
  }

  Future<void> _end(TawafReady current, Emitter<TawafState> emit) async {
    final result = await _endSession();
    if (isClosed) return;
    result.fold(
      // Not cleared: keep the screen open and warn instead of pretending.
      (_) => emit(current.copyWith(
        actionSeq: current.actionSeq + 1,
        saveFailed: true,
      )),
      (_) => emit(const TawafEnded()),
    );
  }
}
