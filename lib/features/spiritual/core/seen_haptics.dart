import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Plays a vibration pattern: alternating wait/vibrate durations in ms, the
/// first entry being the initial wait.
typedef VibrationPatternPlayer = Future<void> Function(List<int> pattern);

/// Single entry point for every haptic in the Manasik hub
/// (docs/spiritual_feature/04-motion-haptics.md), behind a global switch.
///
/// Single taps use the built-in [HapticFeedback]; multi-pulse patterns use the
/// `vibration` package and fall back to a heavy impact on devices without a
/// vibrator or when the plugin is unavailable. Haptics never throw.
abstract final class SeenHaptics {
  /// Global on/off setting. Persisted by the settings feature later.
  static bool enabled = true;

  static const lapCompletePattern = [0, 40, 60, 40];
  static const qiblaLockPattern = [0, 30, 50, 30];
  static const targetReachedPattern = [0, 60, 80, 60];

  static VibrationPatternPlayer _player = _vibrationPackagePlayer;

  /// Replace the pattern backend (tests).
  @visibleForTesting
  static set patternPlayer(VibrationPatternPlayer? player) =>
      _player = player ?? _vibrationPackagePlayer;

  static Future<void> _vibrationPackagePlayer(List<int> pattern) async {
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate(pattern: pattern);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  static void _pattern(List<int> pattern) {
    if (!enabled) return;
    unawaited(
      _player(pattern).catchError((Object _) => HapticFeedback.heavyImpact()),
    );
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// A lap was recorded.
  static void lap() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// A single short buzz of [ms] (prayer alert switched to vibrate).
  static void vibrate(int ms) => _pattern([0, ms]);

  /// Tawaf / Sa'i completed: double pulse.
  static void complete() => _pattern(lapCompletePattern);

  /// Destructive reset (tasbeeh).
  static void reset() => lap();

  /// Tasbeeh target reached.
  static void targetReached() => _pattern(targetReachedPattern);

  /// Qibla lock achieved (call once per lock).
  static void lock() => _pattern(qiblaLockPattern);
}
