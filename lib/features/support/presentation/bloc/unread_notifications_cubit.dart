import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_notifications_usecase.dart';

/// The unread notification count, for a badge.
///
/// There is no push yet (contract 11), so the count is polled about every 45
/// seconds while the app is in the foreground and once when it returns to it.
/// Nothing runs in the background: the timer stops with the app and with the
/// cubit. A failed poll keeps the last number (a badge is never worth an error).
///
/// Owner: the screen that shows the badge (closes it with its provider).
class UnreadNotificationsCubit extends Cubit<int> with WidgetsBindingObserver {
  UnreadNotificationsCubit({
    required GetUnreadNotificationCountUseCase getCount,
    this.interval = const Duration(seconds: 45),
  })  : _getCount = getCount,
        super(0);

  final GetUnreadNotificationCountUseCase _getCount;
  final Duration interval;

  Timer? _timer;
  bool _started = false;
  bool _refreshing = false;

  /// Begins polling (and watching the app's lifecycle). Safe to call twice.
  void start() {
    if (_started || isClosed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  /// Reads the count now (after the inbox was opened and read, for instance).
  Future<void> refresh() async {
    if (_refreshing || isClosed) return;
    _refreshing = true;
    try {
      final result = await _getCount();
      if (isClosed) return;
      result.fold((_) {}, emit);
    } finally {
      _refreshing = false;
    }
  }

  /// The inbox says what it now holds: the badge follows it without a call.
  void adopt(int unreadCount) {
    if (!isClosed && unreadCount >= 0 && unreadCount != state) emit(unreadCount);
  }

  void _resume() {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  @override
  Future<void> close() {
    _pause();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
