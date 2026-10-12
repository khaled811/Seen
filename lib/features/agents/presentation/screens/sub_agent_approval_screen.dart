import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';
import '../widgets/sub_agent_approval_tile.dart';

/// Requests submitted by sub-agents, awaiting this master agent's approval
/// gate (`RequestStatus.pendingAgentApproval`).
class SubAgentApprovalScreen extends StatelessWidget {
  const SubAgentApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: (previous, current) =>
          current is AgentsLoaded && current.approvalActionStatus != ApprovalActionStatus.idle,
      listener: (context, state) {
        final loaded = state as AgentsLoaded;
        switch (loaded.approvalActionStatus) {
          case ApprovalActionStatus.success:
            final message = loaded.approvalActionKind == ApprovalActionKind.reject
                ? l10n.subAgentRejectSuccessMessage
                : l10n.subAgentApproveSuccessMessage;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
            context.read<AgentsBloc>().add(const ApprovalStatusCleared());
          case ApprovalActionStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(loaded.approvalActionError ?? l10n.error)));
            context.read<AgentsBloc>().add(const ApprovalStatusCleared());
          case ApprovalActionStatus.idle:
          case ApprovalActionStatus.submitting:
            break;
        }
      },
      child: Scaffold(
        appBar: SeenTopBar.inner(title: l10n.subAgentApprovalsTitle),
        body: BlocBuilder<AgentsBloc, AgentsState>(
          builder: (context, state) {
            if (state is! AgentsLoaded) {
              return const Center(child: SeenLoader());
            }
            if (state.pendingRequests.isEmpty) {
              return Center(child: Text(l10n.subAgentApprovalsEmptyMessage));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(SeenSpace.s4),
              itemCount: state.pendingRequests.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                child: SubAgentApprovalTile(
                  request: state.pendingRequests[index],
                  isActing: state.approvalActionStatus == ApprovalActionStatus.submitting &&
                      state.approvalActionRequestId == state.pendingRequests[index].id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
