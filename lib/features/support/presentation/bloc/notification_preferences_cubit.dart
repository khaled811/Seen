import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

enum PreferencesStatus { loading, loaded, failure }

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.status = PreferencesStatus.loading,
    this.preferences = NotificationPreferences.defaults,
    this.saveFailures = 0,
  });

  final PreferencesStatus status;
  final NotificationPreferences preferences;

  /// Bumped each time a save was refused and the switch went back (for one snack bar each).
  final int saveFailures;

  NotificationPreferencesState copyWith({PreferencesStatus? status, NotificationPreferences? preferences, int? saveFailures}) =>
      NotificationPreferencesState(
        status: status ?? this.status,
        preferences: preferences ?? this.preferences,
        saveFailures: saveFailures ?? this.saveFailures,
      );

  @override
  List<Object?> get props => [status, preferences, saveFailures];
}

/// The preferences screen (Figma NOTIF-04). A switch moves at once; the change is sent in
/// the background, one request at a time with the latest state, and goes back (with a
/// notice) if the server refuses it.
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit(this._repository) : super(const NotificationPreferencesState());

  final NotificationPreferencesRepository _repository;

  /// What the server last confirmed (what a refused change goes back to).
  NotificationPreferences _confirmed = NotificationPreferences.defaults;
  bool _sending = false;
  bool _pending = false;

  Future<void> load() async {
    emit(state.copyWith(status: PreferencesStatus.loading));
    final r = await _repository.get();
    if (isClosed) {
      return;
    }
    r.fold(
      (Failure f) => emit(state.copyWith(status: PreferencesStatus.failure)),
      (p) {
        _confirmed = p;
        emit(state.copyWith(status: PreferencesStatus.loaded, preferences: p));
      },
    );
  }

  void toggle(NotificationCategory category, bool on) => _change(state.preferences.toggled(category, on));

  void setQuietEnabled(bool on) =>
      _change(state.preferences.withQuietHours(state.preferences.quietHours.copyWith(enabled: on)));

  void setQuietRange(int startMinutes, int endMinutes) => _change(state.preferences
      .withQuietHours(state.preferences.quietHours.copyWith(startMinutes: startMinutes, endMinutes: endMinutes)));

  void _change(NotificationPreferences next) {
    if (state.status != PreferencesStatus.loaded || next == state.preferences) {
      return;
    }
    emit(state.copyWith(preferences: next));
    _flush();
  }

  Future<void> _flush() async {
    if (_sending) {
      _pending = true; // the running request will be followed by one with the latest state
      return;
    }
    _sending = true;
    try {
      do {
        _pending = false;
        final sent = state.preferences;
        final r = await _repository.save(sent);
        if (isClosed) {
          return;
        }
        r.fold(
          (_) {
            // Refused: back to what the server holds, once nothing newer is waiting.
            if (!_pending) {
              emit(state.copyWith(preferences: _confirmed, saveFailures: state.saveFailures + 1));
            }
          },
          (saved) {
            _confirmed = saved;
            if (!_pending) {
              emit(state.copyWith(preferences: saved));
            }
          },
        );
      } while (_pending);
    } finally {
      _sending = false;
    }
  }
}
