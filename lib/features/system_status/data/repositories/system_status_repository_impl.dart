import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/app_status.dart';
import '../../domain/repositories/access_request_repository.dart';
import '../../domain/repositories/app_status_repository.dart';
import '../datasources/system_status_remote_data_source.dart';

class SystemStatusRepositoryImpl
    implements AppStatusRepository, AccessRequestRepository {
  SystemStatusRepositoryImpl({required SystemStatusRemoteDataSource remote})
      : _remote = remote;

  final SystemStatusRemoteDataSource _remote;

  @override
  Future<Either<Failure, AppStatus>> fetch() async =>
      (await _remote.getAppStatus()).map((d) => d.toEntity());

  @override
  Future<Either<Failure, void>> request(String area) async =>
      (await _remote.requestAccess(area)).map((_) {});
}
