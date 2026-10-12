import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/seen_format.dart';
import '../../domain/entities/sub_agent_request_summary.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import 'reject_reason_sheet.dart';
import 'seen_approval_card.dart';

/// [SeenApprovalCard] wired to [AgentsBloc]: approve dispatches directly,
/// reject first collects a reason via [showRejectReasonSheet]. Shared by the
/// list screen's pending-approvals preview and the full approvals screen so
/// the wiring (and the request-summary → card field mapping) isn't
/// duplicated between them.
class SubAgentApprovalTile extends StatelessWidget {
  const SubAgentApprovalTile({super.key, required this.request, required this.isActing});

  final SubAgentRequestSummary request;
  final bool isActing;

  Future<void> _reject(BuildContext context) async {
    final reason = await showRejectReasonSheet(context);
    if (reason != null && context.mounted) {
      context.read<AgentsBloc>().add(SubAgentRequestRejectSubmitted(requestId: request.id, reason: reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SeenApprovalCard(
      // subAgentName is the only identity field this request summary
      // carries — the card's separate "branch" caption line reuses the
      // reference id (real data) rather than a fabricated branch name.
      agentName: request.subAgentName,
      branch: request.referenceId,
      timeAgo: SeenFormat.isolate('${SeenFormat.date(request.submittedAt)} ${SeenFormat.time(request.submittedAt)}'),
      service: request.serviceName,
      travelers: request.travelerCount,
      amount: request.totalPriceCents / 100,
      onApprove: isActing
          ? null
          : () => context.read<AgentsBloc>().add(SubAgentRequestApproveSubmitted(request.id)),
      onReject: isActing ? null : () => _reject(context),
    );
  }
}
