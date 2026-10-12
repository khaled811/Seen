import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_summary.dart';
import '../../domain/repositories/requests_repository.dart';
import '../datasources/requests_remote_data_source.dart';
import '../models/request_detail_dto.dart';
import '../models/request_summary_dto.dart';

class RequestsRepositoryImpl implements RequestsRepository {
  RequestsRepositoryImpl({required RequestsRemoteDataSource remote}) : _remote = remote;

  final RequestsRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<RequestSummary>>> getRequests() async {
    final result = await _remote.getRequests();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<RequestSummaryDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId) async {
    final result = await _remote.getRequestDetail(requestId);
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, RequestDetailDto>).value;
    return Right(dto.toEntity());
  }

  @override
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId) async {
    final result = await _remote.cancelRequest(requestId);
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, RequestDetailDto>).value;
    return Right(dto.toEntity());
  }
}
