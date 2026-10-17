import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/sub_agent.dart';
import '../../domain/entities/sub_agent_request_summary.dart';
import '../../domain/repositories/agents_repository.dart';
import '../datasources/agents_remote_data_source.dart';
import '../models/sub_agent_dto.dart';
import '../models/sub_agent_request_summary_dto.dart';

class AgentsRepositoryImpl implements AgentsRepository {
  AgentsRepositoryImpl({required AgentsRemoteDataSource remote}) : _remote = remote;

  final AgentsRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async {
    final result = await _remote.getSubAgents();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<SubAgentDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests() async {
    final result = await _remote.getPendingApprovalRequests();
    if (result case Left(:final value)) return Left(value);
    final dtos = (result as Right<Failure, List<SubAgentRequestSummaryDto>>).value;
    return Right(dtos.map((dto) => dto.toEntity()).toList());
  }

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async {
    final result = await _remote.approveRequest(requestId);
    if (result case Left(:final value)) return Left(value);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason}) async {
    final result = await _remote.rejectRequest(requestId, reason: reason);
    if (result case Left(:final value)) return Left(value);
    return const Right(null);
  }

  @override
  Future<Either<Failure, SubAgent>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    String? note,
  }) async {
    final result = await _remote.fundSubAgentWallet(
      subAgentId: subAgentId,
      amountCents: amountCents,
      note: note,
    );
    if (result case Left(:final value)) return Left(value);
    final dto = (result as Right<Failure, SubAgentDto>).value;
    return Right(dto.toEntity());
  }
}
