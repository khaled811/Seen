import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/cancel_reason.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/requests_page.dart';
import '../../domain/repositories/requests_repository.dart';
import '../datasources/requests_remote_data_source.dart';

class RequestsRepositoryImpl implements RequestsRepository {
  RequestsRepositoryImpl({required RequestsRemoteDataSource remote}) : _remote = remote;

  final RequestsRemoteDataSource _remote;

  @override
  Future<Either<Failure, RequestsPage>> getRequests({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  }) async {
    final result = await _remote.getRequests(group: group, search: search, offset: offset, limit: limit);
    return result.map((dto) => dto.toEntity());
  }

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async {
    final result = await _remote.getRequestDetail(requestId);
    return result.map((dto) => dto.toEntity());
  }

  @override
  Future<Either<Failure, RequestDetail?>> cancelRequest(String requestId, {CancelReason? reason}) async {
    final cancelled = await _remote.cancelRequest(requestId, reason: reason);
    if (cancelled case Left(:final value)) return Left(value);
    // The cancellation is done. Reload the request so the screen shows its new
    // state; if that fails, say so with null instead of reporting a failure.
    final detail = await _remote.getRequestDetail(requestId);
    return Right(detail.toNullable()?.toEntity());
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) => _remote.remindApprover(requestId);
}
