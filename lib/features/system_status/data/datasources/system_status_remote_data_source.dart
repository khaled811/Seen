import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../models/app_status_dto.dart';

/// App status (maintenance, minimum version) and access requests have no
/// operations in the API (contract section 14), so both are `unsupported_operation`:
/// nothing is sent and nothing is faked (DECISIONS P-06). The app-status check
/// fails open (the app is never blocked on an answer that cannot exist), and the
/// "request access" button reports that it is not available.
abstract interface class SystemStatusRemoteDataSource {
  Future<Either<Failure, AppStatusDto>> getAppStatus();

  Future<Either<Failure, bool>> requestAccess(String area);
}

class SystemStatusRemoteDataSourceImpl implements SystemStatusRemoteDataSource {
  const SystemStatusRemoteDataSourceImpl();

  @override
  Future<Either<Failure, AppStatusDto>> getAppStatus() async => unsupportedOperation('App status');

  @override
  Future<Either<Failure, bool>> requestAccess(String area) async => unsupportedOperation('Requesting access');
}
