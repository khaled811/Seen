// State of the "turn on notifications" screen (Figma NOTIF-03).
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/push_permission_service.dart';

/// What the last tap on "Turn on notifications" achieved.
enum PushOutcome { none, granted, openedSettings, settingsUnavailable, refused }

class PushPermissionState extends Equatable {
  const PushPermissionState({this.status, this.busy = false, this.outcome = PushOutcome.none});

  /// null until the first read.
  final PushPermissionStatus? status;
  final bool busy;
  final PushOutcome outcome;

  PushPermissionState copyWith({PushPermissionStatus? status, bool? busy, PushOutcome? outcome}) =>
      PushPermissionState(status: status ?? this.status, busy: busy ?? this.busy, outcome: outcome ?? this.outcome);

  @override
  List<Object?> get props => [status, busy, outcome];
}

class PushPermissionCubit extends Cubit<PushPermissionState> {
  PushPermissionCubit(this._service) : super(const PushPermissionState());

  final PushPermissionService _service;

  Future<void> load() async {
    final status = await _service.status();
    if (!isClosed) {
      emit(state.copyWith(status: status));
    }
  }

  /// First time: the system prompt. After a refusal: the device settings (the prompt
  /// cannot be shown again). A tap while one is running is ignored.
  Future<void> enable() async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, outcome: PushOutcome.none));
    if (state.status == PushPermissionStatus.denied) {
      final opened = await _service.openSettings();
      if (!isClosed) {
        emit(state.copyWith(busy: false, outcome: opened ? PushOutcome.openedSettings : PushOutcome.settingsUnavailable));
      }
      return;
    }
    final status = await _service.request();
    if (isClosed) {
      return;
    }
    emit(state.copyWith(
      status: status,
      busy: false,
      outcome: switch (status) {
        PushPermissionStatus.granted => PushOutcome.granted,
        _ => PushOutcome.refused,
      },
    ));
  }

  /// Opens the settings from the "declined before" banner.
  Future<void> openSettings() async {
    final opened = await _service.openSettings();
    if (!isClosed) {
      emit(state.copyWith(outcome: opened ? PushOutcome.openedSettings : PushOutcome.settingsUnavailable));
    }
  }
}
