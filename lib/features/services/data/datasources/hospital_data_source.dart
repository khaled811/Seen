import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';

/// Hospital availability has no operation in the API, and no operation of the
/// request flow takes a hospital either (DECISIONS D-15), so this is always
/// `unsupported_operation`: nothing is sent and nothing is faked.
class HospitalRemoteDataSource implements HospitalRepository {
  const HospitalRemoteDataSource();

  @override
  Future<Either<Failure, List<Hospital>>> availability(String serviceId) async =>
      unsupportedOperation('Hospital availability');
}

/// DEBUG ONLY: when the call fails in a debug build, answers with the three hospitals of the
/// Figma frame. Release builds drop the branch (`kDebugMode` is a compile-time constant).
class DebugFallbackHospitalRepository implements HospitalRepository {
  DebugFallbackHospitalRepository(this._real);

  final HospitalRepository _real;

  @override
  Future<Either<Failure, List<Hospital>>> availability(String serviceId) async {
    final r = await _real.availability(serviceId);
    if (debugFallbacksEnabled && r.isLeft()) {
      return const Right([
        Hospital(id: 'h1', name: 'مستشفى الأردن', capacity: 40, remaining: 12),
        Hospital(id: 'h2', name: 'المستشفى التخصصي', capacity: 30, remaining: 3),
        Hospital(id: 'h3', name: 'مستشفى الخالدي', capacity: 25, remaining: 0),
      ]);
    }
    return r;
  }
}
