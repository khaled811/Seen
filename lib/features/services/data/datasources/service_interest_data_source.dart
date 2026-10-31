import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../domain/repositories/service_interest_repository.dart';

/// "Tell me when this service launches" has no operation in the API, so asking
/// is `unsupported_operation` (nothing is sent, nothing is faked, DECISIONS P-06).
/// In a debug build with `USE_DEBUG_FALLBACKS`, the request is treated as done so
/// the sheet can be tried (`kDebugMode` is a compile-time constant).
class ServiceInterestRepositoryImpl implements ServiceInterestRepository {
  ServiceInterestRepositoryImpl();

  final _requested = <String>{};

  @override
  Future<Either<Failure, void>> notifyWhenAvailable(String serviceKey) async {
    if (debugFallbacksEnabled) {
      _requested.add(serviceKey);
      return const Right(null);
    }
    return unsupportedOperation('Notify me when a service is available');
  }

  @override
  bool alreadyRequested(String serviceKey) => _requested.contains(serviceKey);
}
