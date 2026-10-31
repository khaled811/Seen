import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/new_sub_agent.dart';
import '../entities/sub_agent.dart';
import '../entities/sub_agent_profile.dart';
import '../entities/sub_agent_request_summary.dart';

abstract interface class AgentsRepository {
  Future<Either<Failure, List<SubAgent>>> getSubAgents();

  /// Requests submitted by any sub-agent, currently sitting at the master
  /// agent's approval gate (`RequestStatus.pendingAgentApproval`).
  Future<Either<Failure, List<SubAgentRequestSummary>>>
      getPendingApprovalRequests();

  /// Approves the request, committing it forward to management review.
  Future<Either<Failure, void>> approveRequest(String requestId);

  Future<Either<Failure, void>> rejectRequest(String requestId,
      {required String reason});

  /// Transfers [amountCents] from the master agent's wallet into
  /// [subAgentId]'s internal balance. The caller reads the list again for the new
  /// balances (the answer is not the agency's record). Callers must validate `amountCents` against the master
  /// agent's available balance before calling this (see
  /// `FormValidators.maxAmount`) — the backend re-validates regardless.
  ///
  /// [idempotencyKey] is generated once per user action and reused when that same
  /// action is retried: the server never moves the money twice for one key.
  Future<Either<Failure, void>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  });

  /// Adds a sub-agent under the logged-in master agent (Figma AGT-01). The new
  /// record comes back with `invitePending` while the agency is not active yet.
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent newSubAgent);

  /// The profile of one sub-agent (Figma AGT-04): record, balance history and
  /// the agent's requests.
  Future<Either<Failure, SubAgentProfile>> getSubAgentProfile(
      String subAgentId);

  /// Suspends ([active] false) or reactivates a sub-agent (Figma AGT-03). The
  /// server takes no reason, so none is sent.
  Future<Either<Failure, void>> setSubAgentActive({
    required String subAgentId,
    required bool active,
  });
}
