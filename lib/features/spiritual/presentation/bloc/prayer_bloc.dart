import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/time_format.dart';
import '../../di/prayer_module.dart';
import '../../domain/entities/prayer_id.dart';
import '../../domain/entities/prayer_preferences.dart';
import '../../domain/entities/resolved_location.dart';
import '../../domain/services/notification_scheduler.dart';
import '../../domain/usecases/prayer_usecases.dart';
import 'prayer_event.dart';
import 'prayer_state.dart';

/// Prayer times screen: location, day/month views, per-prayer alerts and the
/// reminder schedule.
///
/// Lifecycle: owns one periodic [Timer] (the minute clock), cancelled in
/// [close]. Every preference change is persisted before the next event is
/// handled (events are processed in order), and re-syncs the reminders.
class PrayerBloc extends Bloc<PrayerEvent, PrayerState> {
  PrayerBloc(
    this._m, {
    this.tickInterval = const Duration(seconds: 30),
  }) : super(const PrayerLoading()) {
    on<PrayerStarted>(_onStarted);
    on<PrayerTicked>(_onTicked);
    on<PrayerDateShifted>(_onShift);
    on<PrayerViewChanged>(_onView);
    on<PrayerMarkerSelected>(_onMarker);
    on<PrayerAlertCycled>(_onAlert);
    on<PrayerSettingsChanged>(_onSettings);
    on<PrayerCitySelected>(_onCity);
    on<PrayerNotificationsRequested>(_onNotifications);
    on<PrayerOpenSettingsRequested>(
      (event, emit) => _m.location.openSettings(),
    );
  }

  final PrayerModule _m;
  final Duration tickInterval;
  Timer? _timer;

  PrayerLoaded? get _loaded => state is PrayerLoaded ? state as PrayerLoaded : null;

  DateTime get _now => _minute(_m.clock());

  static DateTime _minute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  Future<void> _onStarted(PrayerStarted event, Emitter<PrayerState> emit) async {
    var prefs = await _m.getPreferences();
    final resolved = await _m.resolveLocation(
      // The first visit is where the user expects the location question.
      askPermission: !prefs.locationPrompted,
      preferCached: prefs.locationPrompted,
    );
    prefs = await _m.getPreferences(); // the resolver may have updated it

    var permission = await _m.notificationPermission();
    var saveFailed = false;
    final wantsReminders =
        prefs.alertModes.values.any((m) => m != AlertMode.silent);
    if (!prefs.notificationsPrompted &&
        wantsReminders &&
        permission == NotificationPermission.notDetermined) {
      permission = await _m.requestNotifications();
      prefs = prefs.copyWith(notificationsPrompted: true);
      saveFailed = (await _m.savePreferences(prefs)).isLeft();
    }
    if (isClosed) return;

    final now = _now;
    final date = dateOnly(now);
    final day = _m.getDay(location: resolved.location, prefs: prefs, date: date);
    final outcome = await _sync(resolved, prefs, SyncOutcome.permissionUnknown);
    if (isClosed) return;
    emit(PrayerLoaded(
      resolved: resolved,
      prefs: prefs,
      view: PrayerView.day,
      date: date,
      day: day,
      hijri: _m.hijri.fromGregorian(date),
      now: now,
      selected: day.next(now)?.$1 ?? PrayerId.dhuhr,
      notifications: permission,
      syncOutcome: outcome,
      saveFailed: saveFailed,
      saveSeq: saveFailed ? 1 : 0,
    ));
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => add(const PrayerTicked()));
  }

  void _onTicked(PrayerTicked event, Emitter<PrayerState> emit) {
    final s = _loaded;
    if (s == null) return;
    final now = _now;
    if (now == s.now) return;
    emit(s.copyWith(now: now));
  }

  void _onShift(PrayerDateShifted event, Emitter<PrayerState> emit) {
    final s = _loaded;
    if (s == null) return;
    final DateTime date;
    if (s.view == PrayerView.day) {
      date = addDays(s.date, event.step);
    } else {
      final target = _shiftHijriMonth(s, event.step);
      if (target == null) return;
      date = target;
    }
    emit(_atDate(s, date));
  }

  /// Same Hijri day number in the neighbouring month (clamped to its length);
  /// null when the calendar tables end.
  DateTime? _shiftHijriMonth(PrayerLoaded s, int step) {
    try {
      var y = s.hijri.year;
      var m = s.hijri.month + step;
      if (m > 12) {
        m = 1;
        y++;
      } else if (m < 1) {
        m = 12;
        y--;
      }
      final day = s.hijri.day.clamp(1, _m.hijri.daysInMonth(y, m));
      return _m.hijri.toGregorian(y, m, day);
    } catch (_) {
      return null;
    }
  }

  PrayerLoaded _atDate(PrayerLoaded s, DateTime date, {PrayerView? view}) {
    final d = dateOnly(date);
    final day = _m.getDay(location: s.resolved.location, prefs: s.prefs, date: d);
    final next = DateTime(s.now.year, s.now.month, s.now.day) == d
        ? day.next(s.now)?.$1
        : null;
    final v = view ?? s.view;
    return s.copyWith(
      view: v,
      date: d,
      day: day,
      hijri: _m.hijri.fromGregorian(d),
      selected: next ?? PrayerId.dhuhr,
      month: v == PrayerView.month
          ? _m.getMonth(
              location: s.resolved.location,
              prefs: s.prefs,
              anyDayOfMonth: d,
            )
          : null,
      clearMonth: v != PrayerView.month,
    );
  }

  void _onView(PrayerViewChanged event, Emitter<PrayerState> emit) {
    final s = _loaded;
    if (s == null || s.view == event.view) return;
    emit(_atDate(s, s.date, view: event.view));
  }

  void _onMarker(PrayerMarkerSelected event, Emitter<PrayerState> emit) {
    final s = _loaded;
    if (s == null || s.selected == event.id) return;
    emit(s.copyWith(selected: event.id));
  }

  Future<void> _onAlert(PrayerAlertCycled event, Emitter<PrayerState> emit) async {
    final s = _loaded;
    if (s == null) return;
    await _applyPrefs(
      s,
      s.prefs.withMode(event.id, s.prefs.modeOf(event.id).next),
      emit,
    );
  }

  Future<void> _onSettings(
    PrayerSettingsChanged event,
    Emitter<PrayerState> emit,
  ) async {
    final s = _loaded;
    if (s == null) return;
    await _applyPrefs(s, event.preferences, emit, recalculate: true);
  }

  Future<void> _onCity(PrayerCitySelected event, Emitter<PrayerState> emit) async {
    final s = _loaded;
    if (s == null) return;
    var prefs = event.cityId == null
        ? s.prefs.copyWith(clearCity: true)
        : s.prefs.copyWith(cityId: event.cityId);
    final saved = await _m.savePreferences(prefs);
    final resolved = await _m.resolveLocation(
      askPermission: event.cityId == null,
    );
    prefs = await _m.getPreferences();
    if (isClosed) return;
    final failed = saved.isLeft();
    final outcome = await _sync(resolved, prefs, s.syncOutcome);
    if (isClosed) return;
    final base = s.copyWith(
      resolved: resolved,
      prefs: prefs,
      syncOutcome: outcome,
      saveFailed: failed,
      saveSeq: failed ? s.saveSeq + 1 : s.saveSeq,
    );
    emit(_atDate(base, s.date));
  }

  Future<void> _onNotifications(
    PrayerNotificationsRequested event,
    Emitter<PrayerState> emit,
  ) async {
    final s = _loaded;
    if (s == null) return;
    final permission = await _m.requestNotifications();
    final prefs = s.prefs.copyWith(notificationsPrompted: true);
    final saved = await _m.savePreferences(prefs);
    final outcome = await _sync(s.resolved, prefs, s.syncOutcome);
    if (isClosed) return;
    emit(s.copyWith(
      prefs: prefs,
      notifications: permission,
      syncOutcome: outcome,
      saveFailed: saved.isLeft(),
      saveSeq: saved.isLeft() ? s.saveSeq + 1 : s.saveSeq,
    ));
  }

  /// Applies [prefs] in memory at once, persists them, then re-syncs the
  /// reminders. A failed write keeps the change on screen and warns.
  Future<void> _applyPrefs(
    PrayerLoaded s,
    PrayerPreferences prefs,
    Emitter<PrayerState> emit, {
    bool recalculate = false,
  }) async {
    final saved = await _m.savePreferences(prefs);
    final outcome = await _sync(s.resolved, prefs, s.syncOutcome);
    if (isClosed) return;
    final failed = saved.isLeft();
    var next = s.copyWith(
      prefs: prefs,
      syncOutcome: outcome,
      saveFailed: failed,
      saveSeq: failed ? s.saveSeq + 1 : s.saveSeq,
    );
    if (recalculate) next = _atDate(next, s.date);
    emit(next);
  }

  Future<SyncOutcome> _sync(
    ResolvedLocation resolved,
    PrayerPreferences prefs,
    SyncOutcome fallback,
  ) async {
    final result = await _m.syncReminders(
      location: resolved.location,
      prefs: prefs,
      now: _m.clock(),
    );
    return result.fold((_) => fallback, (r) => r.outcome);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
