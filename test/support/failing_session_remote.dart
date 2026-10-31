import 'package:seen_booking/core/network/session_remote_data_source.dart';

/// A session API that never touches the network: `refresh` is unavailable and
/// `logout` fails, like an offline device.
class FailingSessionRemote implements SessionRemoteDataSource {
  const FailingSessionRemote();

  @override
  Future<RefreshResponse> refresh() async => const RefreshUnavailable();

  @override
  Future<void> logout() async => throw StateError('offline (test)');
}
