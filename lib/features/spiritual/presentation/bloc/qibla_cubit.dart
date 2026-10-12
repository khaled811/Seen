import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di/prayer_module.dart';
import '../../domain/entities/compass_reading.dart';
import '../../domain/entities/resolved_location.dart';
import '../../domain/utils/angles.dart';
import '../../domain/utils/qibla_lock.dart';
import '../../domain/utils/qibla_math.dart';
import '../../domain/utils/sun_position.dart';
import 'qibla_state.dart';

/// Qibla compass: resolves the location (GPS, else city, else Makkah), turns
/// compass samples into a smoothed true heading, and decides when the user is
/// facing the Kaaba.
///
/// Lifecycle: owns the sensor subscription and a start-up timeout [Timer];
/// [setActive] pauses/resumes them with the app, and [close] cancels both.
class QiblaCubit extends Cubit<QiblaState> {
  QiblaCubit(
    this._m, {
    this.sensorTimeout = const Duration(seconds: 3),
    this.minHeadingStep = 0.2,
  }) : super(const QiblaLoading());

  final PrayerModule _m;

  /// How long to wait for the first sample before declaring "no compass".
  final Duration sensorTimeout;

  /// Heading changes smaller than this (degrees) are not emitted, which keeps
  /// the UI from rebuilding on sensor noise.
  final double minHeadingStep;

  final _filter = HeadingFilter(alpha: 0.15);
  final _lock = QiblaLock();

  StreamSubscription<CompassReading>? _subscription;
  Timer? _timeout;
  double _declination = 0;
  bool _active = true;
  bool _gotSample = false;

  QiblaReady? get _ready => state is QiblaReady ? state as QiblaReady : null;

  Future<void> start() async {
    final prefs = await _m.getPreferences();
    final resolved = await _m.resolveLocation(
      askPermission: !prefs.locationPrompted,
      preferCached: prefs.locationPrompted,
    );
    if (isClosed) return;
    await _show(resolved);
    _listen();
  }

  Future<void> _show(ResolvedLocation resolved) async {
    final loc = resolved.location;
    final distance = QiblaMath.distanceKm(loc.latitude, loc.longitude);
    _declination = _m.compass.headingIsMagnetic
        ? await _safeDeclination(loc.latitude, loc.longitude)
        : 0;
    if (isClosed) return;
    emit(QiblaReady(
      resolved: resolved,
      bearing: QiblaMath.bearing(loc.latitude, loc.longitude),
      distanceKm: distance,
      nearKaaba: distance < QiblaMath.nearKaabaKm,
      sensor: _ready?.sensor ?? SensorStatus.starting,
      sun: SunPosition.at(
        latitude: loc.latitude,
        longitude: loc.longitude,
        time: _m.clock(),
      ),
    ));
  }

  Future<double> _safeDeclination(double lat, double lng) async {
    try {
      return await _m.declination.declinationDegrees(lat, lng);
    } catch (_) {
      return 0; // uncorrected is better than no compass
    }
  }

  void _listen() {
    _subscription?.cancel();
    _timeout?.cancel();
    final stream = _m.compass.readings;
    if (stream == null) {
      _markUnavailable();
      return;
    }
    _gotSample = false;
    _timeout = Timer(sensorTimeout, () {
      if (!_gotSample) _markUnavailable();
    });
    _subscription = stream.listen(
      _onReading,
      onError: (Object _) => _markUnavailable(),
      cancelOnError: false,
    );
  }

  void _onReading(CompassReading r) {
    final s = _ready;
    if (s == null || !_active) return;
    final raw = r.heading;
    if (raw == null || raw.isNaN) {
      // A device without a magnetometer reports null headings.
      if (!_gotSample) _markUnavailable();
      return;
    }
    _gotSample = true;
    _timeout?.cancel();

    final heading = _filter.add(raw + _declination);
    final accuracy = CompassAccuracy.fromDegrees(r.accuracy);
    var locked = false;
    var lockSeq = s.lockSeq;
    if (!s.nearKaaba) {
      final diff = shortestDelta(heading, s.bearing);
      locked = _lock.update(diff);
      if (locked && !s.locked) lockSeq++; // rising edge only
    }

    final moved = s.heading == null ||
        shortestDelta(s.heading!, heading).abs() >= minHeadingStep;
    if (!moved &&
        locked == s.locked &&
        accuracy == s.accuracy &&
        s.sensor == SensorStatus.active) {
      return;
    }
    emit(s.copyWith(
      sensor: SensorStatus.active,
      heading: moved ? heading : s.heading,
      locked: locked,
      accuracy: accuracy,
      lockSeq: lockSeq,
    ));
  }

  void _markUnavailable() {
    final s = _ready;
    _timeout?.cancel();
    _subscription?.cancel();
    _subscription = null;
    if (s == null || isClosed) return;
    if (s.sensor == SensorStatus.unavailable) return;
    emit(s.copyWith(sensor: SensorStatus.unavailable, locked: false));
  }

  /// Pauses the sensor while the app is in the background (battery) and
  /// restarts it, with a clean filter, when it returns.
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    final s = _ready;
    if (!active) {
      _subscription?.cancel();
      _subscription = null;
      _timeout?.cancel();
      return;
    }
    if (s == null || s.sensor == SensorStatus.unavailable) return;
    _filter.reset();
    _lock.reset();
    _listen();
  }

  /// Re-resolves the location after the user picked a city or retried the GPS.
  Future<void> relocate({String? cityId, bool useGps = false}) async {
    var prefs = await _m.getPreferences();
    if (useGps) {
      prefs = prefs.copyWith(clearCity: true);
      await _m.savePreferences(prefs);
    } else if (cityId != null) {
      prefs = prefs.copyWith(cityId: cityId);
      await _m.savePreferences(prefs);
    }
    final resolved = await _m.resolveLocation(askPermission: useGps);
    if (isClosed) return;
    _lock.reset();
    await _show(resolved);
  }

  Future<void> openSettings() => _m.location.openSettings();

  @override
  Future<void> close() {
    _timeout?.cancel();
    _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
