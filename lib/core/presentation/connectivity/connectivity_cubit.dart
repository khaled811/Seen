import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../network/connectivity_monitor.dart';
import '../../network/data_freshness.dart';

enum ConnectivityStatus { online, offline, restored }

class ConnectivityState extends Equatable {
  const ConnectivityState({this.status = ConnectivityStatus.online, this.lastSyncedAt});

  final ConnectivityStatus status;

  /// Last successful backend answer, for "showing data as of ...".
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [status, lastSyncedAt];
}

/// App-wide connectivity (Figma SYS-01): offline → a banner with the last update
/// time; back online → a short "connection is back" confirmation that hides
/// itself.
///
/// Owns the monitor subscription and the hide timer; both released in [close].
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required ConnectivityMonitor monitor,
    required DataFreshness freshness,
    this.restoredFor = const Duration(seconds: 4),
  })  : _monitor = monitor,
        _freshness = freshness,
        super(const ConnectivityState()) {
    _subscription = _monitor.onlineChanges.listen(_apply, onError: (Object _) {});
    _monitor.isOnline().then(_apply);
  }

  final ConnectivityMonitor _monitor;
  final DataFreshness _freshness;
  final Duration restoredFor;
  late final StreamSubscription<bool> _subscription;
  Timer? _hideTimer;

  void _apply(bool online) {
    if (isClosed) return;
    _hideTimer?.cancel();
    if (!online) {
      emit(ConnectivityState(status: ConnectivityStatus.offline, lastSyncedAt: _freshness.value));
      return;
    }
    if (state.status == ConnectivityStatus.offline) {
      emit(ConnectivityState(status: ConnectivityStatus.restored, lastSyncedAt: _freshness.value));
      _hideTimer = Timer(restoredFor, () {
        if (!isClosed) emit(ConnectivityState(lastSyncedAt: _freshness.value));
      });
    }
  }

  /// The banner's "Retry": ask the platform again.
  Future<void> recheck() async => _apply(await _monitor.isOnline());

  @override
  Future<void> close() {
    _hideTimer?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
