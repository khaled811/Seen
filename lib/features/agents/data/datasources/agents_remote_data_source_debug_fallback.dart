import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/new_sub_agent.dart';
import '../models/sub_agent_dto.dart';
import '../models/sub_agent_profile_dto.dart';
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
    if (kDebugMode && result.isLeft()) {
      return Right(_mockSubAgents.values.toList());
    }
    return result;
  }

  @override
  Future<Either<Failure, List<SubAgentRequestSummaryDto>>>
      getPendingApprovalRequests() async {
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
  Future<Either<Failure, bool>> rejectRequest(String requestId,
      {required String reason}) async {
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
    String? note,
  }) async {
    final result = await _real.fundSubAgentWallet(
      subAgentId: subAgentId,
      amountCents: amountCents,
      note: note,
    );
    if (kDebugMode && result.isLeft()) {
      final existing = _mockSubAgents[subAgentId];
      if (existing == null) {
        return const Left(ServerFailure('Sub-agent not found.'));
      }
      final updated = existing.copyWith(
          balanceAmount:
              _addCentsToAmount(existing.balanceAmount, amountCents));
      _mockSubAgents[subAgentId] = updated;
      return Right(updated);
    }
    return result;
  }

  /// Demo rules: a phone ending `4410` belongs to another agent; the credit
  /// limit cannot go under the mock usage or over 5,000.00.
  @override
  Future<Either<Failure, SubAgentDto>> createSubAgent(
      NewSubAgent newSubAgent) async {
    final result = await _real.createSubAgent(newSubAgent);
    if (!(kDebugMode && result.isLeft())) return result;
    if (newSubAgent.phone.endsWith('4410')) {
      return const Left(
          ServerFailure('Phone taken', code: SubAgentIssue.phoneTakenCode));
    }
    final n = _mockSubAgents.length + 1;
    final dto = SubAgentDto(
      id: 'sub-$n',
      name: newSubAgent.agencyName,
      code: 'NEW-${n.toString().padLeft(2, '0')}',
      balanceAmount: '0.00',
      isActive: !newSubAgent.sendInvite,
      invitePending: newSubAgent.sendInvite,
      marginPercent: newSubAgent.marginPercent,
      creditLimitAmount: newSubAgent.creditLimitCents == null
          ? null
          : MoneyParser.decimalStringFromCents(newSubAgent.creditLimitCents!),
      creditUsedAmount: '0.00',
    );
    _mockSubAgents[dto.id] = dto;
    return Right(dto);
  }

  @override
  Future<Either<Failure, SubAgentDto>> updateCreditLimit(
      {required String subAgentId, required int limitCents}) async {
    final result = await _real.updateCreditLimit(
        subAgentId: subAgentId, limitCents: limitCents);
    if (!(kDebugMode && result.isLeft())) return result;
    final existing = _mockSubAgents[subAgentId];
    if (existing == null) {
      return const Left(ServerFailure('Sub-agent not found.'));
    }
    final used = existing.creditUsedAmount == null
        ? 0
        : MoneyParser.centsFromDecimalString(existing.creditUsedAmount!);
    if (limitCents < used) {
      return Left(ServerFailure('Below usage',
          code: SubAgentIssue.limitBelowUsageCode,
          details: {'usedCents': used}));
    }
    if (limitCents > 500000) {
      return const Left(ServerFailure('Above allowed',
          code: SubAgentIssue.limitAboveAllowedCode,
          details: {'maxCents': 500000}));
    }
    final updated = existing.copyWith(
        creditLimitAmount: MoneyParser.decimalStringFromCents(limitCents));
    _mockSubAgents[subAgentId] = updated;
    return Right(updated);
  }

  /// Demo data: the mock agent plus a canned balance history and requests.
  @override
  Future<Either<Failure, SubAgentProfileDto>> getSubAgentProfile(
      String subAgentId) async {
    final result = await _real.getSubAgentProfile(subAgentId);
    if (!(kDebugMode && result.isLeft())) return result;
    final agent = _mockSubAgents[subAgentId];
    if (agent == null) return const Left(ServerFailure('Sub-agent not found.'));
    final now = DateTime.now();
    return Right(SubAgentProfileDto(
      agent: agent,
      city: 'عدن',
      memberSince: DateTime(2024, 3, 1),
      monthlyRequestCount: 412,
      inProgressRequestCount: 3,
      ledger: [
        LedgerEntryDto(
          id: 'l1',
          title: 'تمويل من الوكيل الرئيسي',
          amount: '300.00',
          isCredit: true,
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        LedgerEntryDto(
          id: 'l2',
          title: 'SB-20484 · حجز طيران',
          amount: '1240.00',
          isCredit: false,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        LedgerEntryDto(
          id: 'l3',
          title: 'تمويل من الوكيل الرئيسي',
          amount: '1000.00',
          isCredit: true,
          createdAt: now.subtract(const Duration(days: 4)),
        ),
      ],
      requests: [
        AgentRequestDto(
          id: 'r1',
          referenceId: 'SB-20488',
          serviceName: 'تأشيرة السعودية',
          status: 'processing',
          submittedAt: now.subtract(const Duration(days: 1)),
        ),
        AgentRequestDto(
          id: 'r2',
          referenceId: 'SB-20487',
          serviceName: 'تأشيرة مصر',
          status: 'under_review',
          submittedAt: now.subtract(const Duration(days: 2)),
        ),
        AgentRequestDto(
          id: 'r3',
          referenceId: 'SB-20470',
          serviceName: 'تأشيرة السعودية',
          status: 'completed',
          submittedAt: now.subtract(const Duration(days: 9)),
        ),
      ],
    ));
  }

  @override
  Future<Either<Failure, SubAgentDto>> setSubAgentActive({
    required String subAgentId,
    required bool active,
    String? reason,
  }) async {
    final result = await _real.setSubAgentActive(
        subAgentId: subAgentId, active: active, reason: reason);
    if (!(kDebugMode && result.isLeft())) return result;
    final existing = _mockSubAgents[subAgentId];
    if (existing == null) {
      return const Left(ServerFailure('Sub-agent not found.'));
    }
    final updated = existing.copyWith(isActive: active);
    _mockSubAgents[subAgentId] = updated;
    return Right(updated);
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
      creditLimitAmount: '500.00',
      creditUsedAmount: '380.00',
    ),
    SubAgentDto(
      id: 'sub-2',
      name: 'Alexandria Branch',
      code: 'ALX-02',
      balanceAmount: '850.50',
      isActive: true,
      marginPercent: 5.0,
      creditLimitAmount: '1000.00',
      creditUsedAmount: '120.00',
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
