import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/airline_circular.dart';

abstract interface class AirlineCircularRepository {
  /// The agent's issued security approvals, newest first.
  Future<Either<Failure, List<ApprovedSecurityRequest>>> approvedRequests();

  /// The travelers of [approvalId], to be copied into the circular.
  Future<Either<Failure, CircularPrefill>> prefill(String approvalId);

  /// Sends the circular; resolves its id.
  Future<Either<Failure, String>> submit(CircularSubmission submission);
}
