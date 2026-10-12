import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../domain/entities/sub_agent.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';
import '../widgets/fund_sub_agent_sheet.dart';
import '../widgets/seen_sub_agent_row.dart';
import '../widgets/sub_agent_approval_tile.dart';
import 'sub_agent_approval_screen.dart';

/// Entry point for the Sub-Agents feature: a quick pending-approvals
/// preview, then the full branch directory.
class SubAgentsListScreen extends StatelessWidget {
  const SubAgentsListScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell: no back button.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createAgentsBloc()
        ..add(const AgentsLoadRequested()),
      child: _SubAgentsView(embedded: embedded),
    );
  }
}

/// A route pushed via Navigator isn't a descendant of this screen's
/// BlocProvider (it attaches to the Navigator's Overlay), so the same Bloc
/// instance must be forwarded explicitly. Shared by the top bar's badge
/// button and the pending-approvals section's "See all" link.
void _openApprovals(BuildContext context) {
  final bloc = context.read<AgentsBloc>();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: bloc, child: const SubAgentApprovalScreen()),
    ),
  );
}

class _SubAgentsView extends StatelessWidget {
  const _SubAgentsView({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SeenTopBar.inner(
        title: l10n.subAgentsTitle,
        showBack: !embedded,
        trailing: BlocBuilder<AgentsBloc, AgentsState>(
          buildWhen: (previous, current) => current is AgentsLoaded,
          builder: (context, state) {
            final pendingCount = state is AgentsLoaded ? state.pendingRequests.length : 0;
            return SeenIconButton(
              icon: SeenIcons.file,
              semanticLabel: l10n.subAgentApprovalsTitle,
              badge: pendingCount,
              onPressed: () => _openApprovals(context),
            );
          },
        ),
      ),
      body: BlocBuilder<AgentsBloc, AgentsState>(
        builder: (context, state) {
          return switch (state) {
            AgentsInitial() || AgentsLoading() => const Center(child: SeenLoader()),
            AgentsFailure(:final message) => _ErrorView(message: message),
            AgentsLoaded() => _LoadedView(state: state),
          };
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context.read<AgentsBloc>().add(const AgentsLoadRequested()),
          ),
        ],
      ),
    );
  }
}

/// Quick preview cap on the list screen — the full, unbounded list lives on
/// [SubAgentApprovalScreen] behind the "See all" link and the top bar badge.
const _pendingPreviewLimit = 3;

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final AgentsLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preview = state.pendingRequests.take(_pendingPreviewLimit).toList();
    return RefreshIndicator(
      onRefresh: () async {
        context.read<AgentsBloc>().add(const AgentsLoadRequested());
        await context.read<AgentsBloc>().stream.firstWhere((s) => s is! AgentsLoading);
      },
      child: ListView(
        padding: const EdgeInsets.all(SeenSpace.s4),
        children: [
          if (preview.isNotEmpty) ...[
            SeenSectionHeader(
              title: l10n.subAgentApprovalsTitle,
              count: state.pendingRequests.length,
              actionLabel: state.pendingRequests.length > _pendingPreviewLimit ? l10n.homeSeeAllAction : null,
              onAction: () => _openApprovals(context),
            ),
            for (final request in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                child: SubAgentApprovalTile(
                  request: request,
                  isActing: state.approvalActionStatus == ApprovalActionStatus.submitting &&
                      state.approvalActionRequestId == request.id,
                ),
              ),
            const SizedBox(height: SeenSpace.s3),
          ],
          SeenSectionHeader(title: l10n.subAgentsDirectoryTitle),
          SeenListGroup(children: [
            for (final subAgent in state.subAgents)
              _SubAgentRowEntry(
                subAgent: subAgent,
                masterAvailableBalanceCents: state.masterWalletBalance?.availableCents ?? 0,
              ),
          ]),
        ],
      ),
    );
  }
}

class _SubAgentRowEntry extends StatelessWidget {
  const _SubAgentRowEntry({required this.subAgent, required this.masterAvailableBalanceCents});

  final SubAgent subAgent;
  final int masterAvailableBalanceCents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SeenSubAgentRow(
      name: subAgent.name,
      // No city field on SubAgent yet — the branch code is the closest real
      // identity string available (see the widget's own doc comment).
      city: subAgent.code,
      marginLabel: subAgent.marginPercent != null ? '${subAgent.marginPercent}%' : l10n.serviceFactUnavailable,
      balance: subAgent.balanceCents / 100,
      suspended: !subAgent.isActive,
      onTap: () => showFundSubAgentSheet(
        context,
        subAgent: subAgent,
        masterAvailableBalanceCents: masterAvailableBalanceCents,
      ),
    );
  }
}
