import 'package:flutter/foundation.dart';

/// When the app last got a successful answer from the backend. The offline
/// banner shows it ("showing data as of 10:42"). Written by `GraphQLService`,
/// read by the connectivity cubit; in memory only (a cold start offline has no
/// time to show, and the banner then omits it).
class DataFreshness {
  final ValueNotifier<DateTime?> _lastSuccess = ValueNotifier<DateTime?>(null);

  ValueListenable<DateTime?> get lastSuccess => _lastSuccess;

  DateTime? get value => _lastSuccess.value;

  void markFresh([DateTime? at]) => _lastSuccess.value = at ?? DateTime.now();
}
