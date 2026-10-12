import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/request_detail.dart';
import '../entities/request_summary.dart';

abstract interface class RequestsRepository {
  Future<Either<Failure, List<RequestSummary>>> getRequests();

  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId);

  /// Returns the request's updated detail on success.
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId);
}
