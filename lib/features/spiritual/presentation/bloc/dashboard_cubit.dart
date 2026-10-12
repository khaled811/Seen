import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_dashboard_usecase.dart';
import 'dashboard_state.dart';

/// Loads the dashboard snapshot and keeps the "next prayer" countdown live.
///
/// Lifecycle: the cubit owns one periodic [Timer] (every [tickInterval]); it
/// is cancelled by [setActive]`(false)` when the hub is not visible and always
/// in [close].
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(
    this._getDashboard, {
    DateTime Function()? clock,
    this.tickInterval = const Duration(seconds: 30),
  })  : _clock = clock ?? DateTime.now,
        super(const DashboardInitial());

  final GetDashboardUseCase _getDashboard;
  final DateTime Function() _clock;
  final Duration tickInterval;

  Timer? _timer;
  bool _active = true;

  Future<void> load() async {
    if (state is DashboardLoading) return; // drop duplicate requests
    emit(const DashboardLoading());
    final result = await _getDashboard();
    if (isClosed) return;
    result.fold(
      (failure) => emit(DashboardFailure(failure.message)),
      (snapshot) {
        emit(DashboardLoaded(
          snapshot: snapshot,
          next: snapshot.prayers.next(_clock()),
        ));
        _restartTimer();
      },
    );
  }

  /// Re-reads the snapshot without the loading state (no spinner flash), e.g.
  /// after returning from the Tawaf screen. A failed refresh keeps the data
  /// already on screen.
  Future<void> refresh() async {
    if (state is! DashboardLoaded) return load();
    final result = await _getDashboard();
    if (isClosed) return;
    result.fold(
      (_) {},
      (snapshot) => emit(DashboardLoaded(
        snapshot: snapshot,
        next: snapshot.prayers.next(_clock()),
      )),
    );
  }

  /// Recomputes the countdown against the clock. Emits only on change.
  void refreshClock() {
    final current = state;
    if (current is! DashboardLoaded) return;
    emit(DashboardLoaded(
      snapshot: current.snapshot,
      next: current.snapshot.prayers.next(_clock()),
    ));
  }

  /// Pauses the ticker while the hub is off-screen (battery) and refreshes
  /// immediately when it becomes visible again.
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (active) {
      refreshClock();
      _restartTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_active) return;
    _timer = Timer.periodic(tickInterval, (_) => refreshClock());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
