import 'package:fpdart/fpdart.dart';

import '../../../../core/config/debug_fallbacks.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_registration.dart';
import 'agency_registration_remote_data_source.dart';

/// DEBUG ONLY (opt-in with `USE_DEBUG_FALLBACKS`): when the real call fails in a
/// debug build, the registration is treated as created so the flow can be tried.
/// `kDebugMode` is a compile-time constant, so release builds drop the branch.
class DebugFallbackAgencyRegistrationRemoteDataSource implements AgencyRegistrationRemoteDataSource {
  DebugFallbackAgencyRegistrationRemoteDataSource(this._real);

  final AgencyRegistrationRemoteDataSource _real;

  @override
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  }) async {
    final result = await _real.register(draft: draft, password: password, consent: consent);
    return debugFallbacksEnabled && result.isLeft() ? const Right(null) : result;
  }
}
