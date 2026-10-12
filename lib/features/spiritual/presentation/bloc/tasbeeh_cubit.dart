import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tasbeeh.dart';
import '../../domain/repositories/tasbeeh_repository.dart';
import '../../domain/services/screen_awake.dart';
import '../../domain/utils/tasbeeh_math.dart';

enum TasbeehStatus { loading, ready, failure }

class TasbeehState extends Equatable {
  const TasbeehState({
    this.status = TasbeehStatus.loading,
    this.adhkar = const [],
    this.progress,
    this.saveFailed = false,
  });

  final TasbeehStatus status;
  final List<TasbeehDhikr> adhkar;
  final TasbeehProgress? progress;

  /// Progress could not be written to the device (shown once per outage).
  final bool saveFailed;

  TasbeehDhikr? get dhikr {
    final id = progress?.dhikrId;
    for (final d in adhkar) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, adhkar, progress, saveFailed];
}

/// The digital tasbeeh.
///
/// Every change is applied to the state first, so the screen answers a tap in
/// the same frame, and persisted right after. Holds the screen awake from
/// [load] until [close].
class TasbeehCubit extends Cubit<TasbeehState> {
  TasbeehCubit({
    required DhikrCatalog catalog,
    required TasbeehRepository repository,
    required ScreenAwake screenAwake,
    DateTime Function()? clock,
  })  : _catalog = catalog,
        _repository = repository,
        _awake = screenAwake,
        _clock = clock ?? DateTime.now,
        super(const TasbeehState());

  final DhikrCatalog _catalog;
  final TasbeehRepository _repository;
  final ScreenAwake _awake;
  final DateTime Function() _clock;

  bool _awakeHeld = false;

  Future<void> load() async {
    _awakeHeld = true;
    unawaited(_awake.hold());
    final adhkar = await _catalog.adhkar();
    final saved = await _repository.load();
    if (isClosed) return;
    adhkar.fold(
      (_) => emit(const TasbeehState(status: TasbeehStatus.failure)),
      (list) {
        final now = _clock();
        // An unreadable save is not fatal: start over from the first dhikr.
        var progress = saved.fold((_) => null, (p) => p) ??
            TasbeehProgress(
              dhikrId: list.first.id,
              day: TasbeehMath.dayKey(now),
            );
        if (!list.any((d) => d.id == progress.dhikrId)) {
          progress = TasbeehMath.reset(progress.copyWith(dhikrId: list.first.id));
        }
        emit(TasbeehState(
          status: TasbeehStatus.ready,
          adhkar: list,
          progress: TasbeehMath.rollDay(progress, now),
        ));
      },
    );
  }

  /// Counts once. Returns true when this tap completed the round, so the
  /// screen can play the target-reached haptic.
  bool tap() {
    final before = state.progress;
    if (before == null) return false;
    final after = TasbeehMath.tap(before, _clock());
    _apply(after);
    return after.complete && !before.complete;
  }

  /// Zeroes the count; today's tallies stay.
  void reset() => _change(TasbeehMath.reset);

  void selectDhikr(String id) {
    final p = state.progress;
    if (p == null || !state.adhkar.any((d) => d.id == id)) return;
    _apply(TasbeehMath.selectDhikr(p, id, _clock()));
  }

  void selectTarget(TasbeehTarget target) =>
      _change((p) => TasbeehMath.selectTarget(p, target));

  void _change(TasbeehProgress Function(TasbeehProgress) change) {
    final p = state.progress;
    if (p != null) _apply(change(p));
  }

  void _apply(TasbeehProgress next) {
    if (next == state.progress) return;
    emit(TasbeehState(
      status: state.status,
      adhkar: state.adhkar,
      progress: next,
      saveFailed: state.saveFailed,
    ));
    unawaited(_persist(next));
  }

  Future<void> _persist(TasbeehProgress progress) async {
    final result = await _repository.save(progress);
    if (isClosed) return;
    result.fold(
      (_) {
        if (!state.saveFailed) {
          emit(TasbeehState(
            status: state.status,
            adhkar: state.adhkar,
            progress: state.progress,
            saveFailed: true,
          ));
        }
      },
      (_) {
        if (state.saveFailed) {
          emit(TasbeehState(
            status: state.status,
            adhkar: state.adhkar,
            progress: state.progress,
          ));
        }
      },
    );
  }

  @override
  Future<void> close() async {
    if (_awakeHeld) await _awake.release();
    return super.close();
  }
}
