import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network connection. "Online" means a transport
/// exists (Wi-Fi / mobile / ethernet), not that our backend answers; the
/// banner is a hint, and every failed request still reports its own error.
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits whenever the state may have changed.
  Stream<bool> get onlineChanges;
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _online(ConnectivityResult r) => r != ConnectivityResult.none;

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } catch (_) {
      // The platform could not say (no plugin on this platform): assume online;
      // every request still reports its own failure.
      return true;
    }
  }

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_online).handleError((Object _) {});
}
