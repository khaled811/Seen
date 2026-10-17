import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/cancel_reason.dart';
import '../entities/request_detail.dart';
import '../entities/request_summary.dart';

abstract interface class RequestsRepository {
  Future<Either<Failure, List<RequestSummary>>> getRequests();

  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId);

  /// Returns the request's updated detail on success. A request the server
  /// will not release fails with `ServerFailure.code == 'NOT_CANCELLABLE'`.
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId, {CancelReason? reason});

  /// Reminds the approver of a request waiting on approval.
  Future<Either<Failure, void>> remindApprover(String requestId);
}
