import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_mode.dart';
import '../../domain/repositories/mode_repository.dart';

class ModeState extends Equatable {
  const ModeState({
    this.mode = AppMode.agent,
    this.restored = false,
    this.manasikTab = 0,
  });

  final AppMode mode;

  /// False until the persisted mode has been read; the shell renders nothing
  /// before that so the user never sees a flip on launch.
  final bool restored;

  /// Selected tab of the Manasik bottom navigation (not persisted).
  final int manasikTab;

  ModeState copyWith({AppMode? mode, bool? restored, int? manasikTab}) =>
      ModeState(
        mode: mode ?? this.mode,
        restored: restored ?? this.restored,
        manasikTab: manasikTab ?? this.manasikTab,
      );

  @override
  List<Object?> get props => [mode, restored, manasikTab];
}

/// Owns which workspace (agent / Manasik) is showing, persisted across
/// launches.
class ModeCubit extends Cubit<ModeState> {
  ModeCubit(this._repository) : super(const ModeState());

  static const manasikTabCount = 4;

  final ModeRepository _repository;

  Future<void> restore() async {
    final mode = await _repository.load();
    if (isClosed) return;
    emit(state.copyWith(mode: mode, restored: true));
  }

  void select(AppMode mode) {
    if (!state.restored || state.mode == mode) return;
    emit(state.copyWith(mode: mode));
    unawaited(_repository.save(mode));
  }

  void toggle() => select(
        state.mode == AppMode.agent ? AppMode.manasik : AppMode.agent,
      );

  void selectManasikTab(int index) {
    if (index < 0 || index >= manasikTabCount || index == state.manasikTab) {
      return;
    }
    emit(state.copyWith(manasikTab: index));
  }
}
