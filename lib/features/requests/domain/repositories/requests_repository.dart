import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/cancel_reason.dart';
import '../entities/request_detail.dart';
import '../entities/requests_page.dart';

abstract interface class RequestsRepository {
  /// One page of the agency's requests ([group] is a [RequestsGroup] wire
  /// value), filtered and searched by the server.
  Future<Either<Failure, RequestsPage>> getRequests({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  });

  Future<Either<Failure, RequestDetail>> getRequestDetail(String requestId);

  /// Returns the request's updated detail on success. A request the server
  /// will not release fails with `ServerFailure.code == 'NOT_CANCELLABLE'`.
  /// Cancels the request. The answer is the refreshed detail, or null when the
  /// cancellation went through but the detail could not be reloaded.
  Future<Either<Failure, RequestDetail?>> cancelRequest(String requestId, {CancelReason? reason});

  /// Reminds the approver of a request waiting on approval.
  Future<Either<Failure, void>> remindApprover(String requestId);
}
