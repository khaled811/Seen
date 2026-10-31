import 'package:fpdart/fpdart.dart';

import '../../../../core/config/debug_fallbacks.dart';
import '../../../../core/error/failure.dart';
import 'password_recovery_remote_data_source.dart';

/// DEBUG ONLY (opt-in with `USE_DEBUG_FALLBACKS`): when the real call fails in a
/// debug build, the request is treated as sent so the screen can be tried.
/// `kDebugMode` is a compile-time constant, so release builds drop the branch.
class DebugFallbackPasswordRecoveryRemoteDataSource implements PasswordRecoveryRemoteDataSource {
  DebugFallbackPasswordRecoveryRemoteDataSource(this._real);

  final PasswordRecoveryRemoteDataSource _real;

  @override
  Future<Either<Failure, void>> requestReset({required String email}) async {
    final result = await _real.requestReset(email: email);
    return debugFallbacksEnabled && result.isLeft() ? const Right(null) : result;
  }
}
