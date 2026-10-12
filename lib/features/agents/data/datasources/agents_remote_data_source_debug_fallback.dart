import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../models/sub_agent_dto.dart';
import '../models/sub_agent_request_summary_dto.dart';
import 'agents_remote_data_source.dart';

/// DEBUG ONLY — decorates a real [AgentsRemoteDataSource] and, only when a
/// real call fails in a debug build, substitutes canned sub-agents and
/// pending-approval requests. Same pattern (and the same reasoning) as the
/// wallet/services/requests debug fallbacks: `kDebugMode` is a compile-time
/// constant, so every fallback branch below is dead-code-eliminated in
/// release.
class DebugFallbackAgentsRemoteDataSource implements AgentsRemoteDataSource {
  DebugFallbackAgentsRemoteDataSource(this._real);

  final AgentsRemoteDataSource _real;

  /// In-memory only — reset on app restart, never touches real persistence.
  final Map<String, SubAgentDto> _mockSubAgents = _seedSubAgents();
  final Map<String, SubAgentRequestSummaryDto> _mockPendingRequests =
      _seedPendingRequests();

  @override
  Future<Either<Failure, List<SubAgentDto>>> getSubAgents() async {
    final result = await _real.getSubAgents();
    if (kDebugMode && result.isLeft()) return Right(_mockSubAgents.values.toList());
    return result;
  }

  @override
  Future<Either<Failure, List<SubAgentRequestSummaryDto>>> getPendingApprovalRequests() async {
    final result = await _real.getPendingApprovalRequests();
    if (kDebugMode && result.isLeft()) {
      return Right(_mockPendingRequests.values.toList());
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> approveRequest(String requestId) async {
    final result = await _real.approveRequest(requestId);
    if (kDebugMode && result.isLeft()) {
      if (!_mockPendingRequests.containsKey(requestId)) {
        return const Left(ServerFailure('Request not found.'));
      }
      _mockPendingRequests.remove(requestId);
      return const Right(true);
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> rejectRequest(String requestId, {required String reason}) async {
    final result = await _real.rejectRequest(requestId, reason: reason);
    if (kDebugMode && result.isLeft()) {
      if (!_mockPendingRequests.containsKey(requestId)) {
        return const Left(ServerFailure('Request not found.'));
      }
      _mockPendingRequests.remove(requestId);
      return const Right(true);
    }
    return result;
  }

  @override
  Future<Either<Failure, SubAgentDto>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
  }) async {
    final result = await _real.fundSubAgentWallet(
      subAgentId: subAgentId,
      amountCents: amountCents,
    );
    if (kDebugMode && result.isLeft()) {
      final existing = _mockSubAgents[subAgentId];
      if (existing == null) {
        return const Left(ServerFailure('Sub-agent not found.'));
      }
      final updated = SubAgentDto(
        id: existing.id,
        name: existing.name,
        code: existing.code,
        balanceAmount: _addCentsToAmount(existing.balanceAmount, amountCents),
        isActive: existing.isActive,
        marginPercent: existing.marginPercent,
      );
      _mockSubAgents[subAgentId] = updated;
      return Right(updated);
    }
    return result;
  }

  String _addCentsToAmount(String decimalAmount, int addCents) {
    final currentCents = MoneyParser.centsFromDecimalString(decimalAmount);
    return MoneyParser.decimalStringFromCents(currentCents + addCents);
  }
}

Map<String, SubAgentDto> _seedSubAgents() {
  const subAgents = [
    SubAgentDto(
      id: 'sub-1',
      name: 'Cairo Branch',
      code: 'CAI-01',
      balanceAmount: '2400.00',
      isActive: true,
      marginPercent: 3.0,
    ),
    SubAgentDto(
      id: 'sub-2',
      name: 'Alexandria Branch',
      code: 'ALX-02',
      balanceAmount: '850.50',
      isActive: true,
      marginPercent: 5.0,
    ),
    SubAgentDto(
      id: 'sub-3',
      name: 'Giza Branch',
      code: 'GIZ-03',
      balanceAmount: '0.00',
      isActive: false,
    ),
    SubAgentDto(
      id: 'sub-4',
      name: 'Luxor Branch',
      code: 'LUX-04',
      balanceAmount: '1200.00',
      isActive: true,
      marginPercent: 2.5,
    ),
  ];
  return {for (final s in subAgents) s.id: s};
}

Map<String, SubAgentRequestSummaryDto> _seedPendingRequests() {
  final now = DateTime.now();
  final requests = [
    SubAgentRequestSummaryDto(
      id: 'sub-req-1',
      referenceId: 'SB-2001',
      subAgentName: 'Cairo Branch',
      serviceName: 'Egypt National Security Approval',
      travelerCount: 2,
      totalPriceAmount: '300.00',
      submittedAt: now.subtract(const Duration(hours: 5)),
    ),
    SubAgentRequestSummaryDto(
      id: 'sub-req-2',
      referenceId: 'SB-2002',
      subAgentName: 'Alexandria Branch',
      serviceName: 'Egypt Military Intelligence Approval',
      travelerCount: 1,
      totalPriceAmount: '200.00',
      submittedAt: now.subtract(const Duration(hours: 20)),
    ),
    SubAgentRequestSummaryDto(
      id: 'sub-req-3',
      referenceId: 'SB-2003',
      subAgentName: 'Luxor Branch',
      serviceName: 'Egypt National Security Approval',
      travelerCount: 3,
      totalPriceAmount: '450.00',
      submittedAt: now.subtract(const Duration(days: 1, hours: 4)),
    ),
  ];
  return {for (final r in requests) r.id: r};
}
