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
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests();

  /// Approves the request, committing it forward to management review.
  Future<Either<Failure, void>> approveRequest(String requestId);

  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason});

  /// Transfers [amountCents] from the master agent's wallet into
  /// [subAgentId]'s internal balance. Returns the sub-agent's updated
  /// record. Callers must validate `amountCents` against the master
  /// agent's available balance before calling this (see
  /// `FormValidators.maxAmount`) — the backend re-validates regardless.
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    String? note,
  });

  /// Adds a sub-agent under the logged-in master agent (Figma AGT-01). The new
  /// record comes back with `invitePending` when an invitation was sent.
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent newSubAgent);

  /// Sets the credit the master agent grants [subAgentId] (Figma AGT-02).
  Future<Either<Failure, SubAgent>> updateCreditLimit({required String subAgentId, required int limitCents});

  /// The profile of one sub-agent (Figma AGT-04): record, balance history and
  /// the agent's requests.
  Future<Either<Failure, SubAgentProfile>> getSubAgentProfile(String subAgentId);

  /// Suspends ([active] false, with a [reason]) or reactivates a sub-agent
  /// (Figma AGT-03). Returns the updated record.
  Future<Either<Failure, SubAgent>> setSubAgentActive({
    required String subAgentId,
    required bool active,
    String? reason,
  });
}
