import 'dart:async';

import 'package:flutter/widgets.dart';

/// Why a reveal was refused (the server's `too_many_attempts` and `permission_denied`).
sealed class RevealFailure implements Exception {}

class RevealRateLimited extends RevealFailure {
  RevealRateLimited(this.retryAfter);

  final Duration retryAfter;
}

class RevealForbidden extends RevealFailure {}

/// Holds at most ONE revealed sensitive value per screen, in memory only, for [duration].
///
/// - Revealing another value hides the first.
/// - It hides on its own at the end of the time, when the app goes to the background and when
///   the screen is disposed. A late answer for a value that was hidden meanwhile is dropped.
/// - Nothing here is logged or written anywhere; [onSecureChanged] tells the platform to block
///   screenshots while a value is visible.
class RevealController extends ChangeNotifier with WidgetsBindingObserver {
  RevealController({required this.fetch, this.duration = const Duration(seconds: 30), this.onSecureChanged}) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Asks the server for the clear text of one value; throws [RevealRateLimited] or [RevealForbidden].
  final Future<String> Function(String id) fetch;
  final Duration duration;
  final ValueChanged<bool>? onSecureChanged;

  String? _id;
  String? _value;
  int _secondsLeft = 0;
  bool _loading = false;
  Timer? _timer;
  DateTime? _blockedUntil;
  bool _forbidden = false;
  bool _failed = false;
  int _ticket = 0;
  bool _disposed = false;

  /// The value that is visible or being fetched.
  String? get id => _id;
  bool isLoading(String id) => _loading && _id == id;
  String? valueOf(String id) => _id == id ? _value : null;
  int get secondsLeft => _secondsLeft;

  /// The server said this person may not reveal (`permission_denied`).
  bool get forbidden => _forbidden;

  /// The last reveal failed for another reason (connection, unknown value).
  bool get failed => _failed;

  /// Time left of a rate limit; not a listenable, the screen ticks it.
  Duration? get blockedFor {
    final until = _blockedUntil;
    if (until == null) {
      return null;
    }
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<void> reveal(String id) async {
    if (_forbidden || blockedFor != null || (_loading && _id == id)) {
      return;
    }
    hide();
    final ticket = ++_ticket;
    _id = id;
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      final value = await fetch(id);
      if (_disposed || ticket != _ticket) {
        return;
      }
      _value = value;
      _loading = false;
      _secondsLeft = duration.inSeconds;
      onSecureChanged?.call(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          hide();
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
    } on RevealRateLimited catch (e) {
      if (_disposed || ticket != _ticket) {
        return;
      }
      _blockedUntil = DateTime.now().add(e.retryAfter);
      _clear();
    } on RevealForbidden {
      if (_disposed || ticket != _ticket) {
        return;
      }
      _forbidden = true;
      _clear();
    } catch (_) {
      if (_disposed || ticket != _ticket) {
        return;
      }
      _failed = true;
      _clear();
    }
  }

  void hide() {
    _ticket++;
    if (_disposed) {
      return;
    }
    _clear();
  }

  void _clear() {
    final wasVisible = _value != null;
    _timer?.cancel();
    _timer = null;
    _id = null;
    _value = null;
    _loading = false;
    _secondsLeft = 0;
    if (wasVisible) {
      onSecureChanged?.call(false);
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      hide();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_value != null) {
      onSecureChanged?.call(false);
    }
    super.dispose();
  }
}
