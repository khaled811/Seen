import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/extended_fab.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/search_field.dart';
import '../../../../core/presentation/widgets/segmented_control.dart';
import '../../../../core/presentation/widgets/stat_card.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';
import '../widgets/fund_sub_agent_sheet.dart';
import '../widgets/seen_sub_agent_card.dart';
import '../widgets/sub_agent_approval_tile.dart';
import 'sub_agent_approval_screen.dart';

/// Sub-agent network (Figma 13): overview metrics, a quick pending-approvals
/// preview, then the searchable / filterable branch directory.
class SubAgentsListScreen extends StatelessWidget {
  const SubAgentsListScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell: no back button.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createAgentsBloc()..add(const AgentsLoadRequested()),
      child: _SubAgentsView(embedded: embedded),
    );
  }
}

/// A route pushed via Navigator is not a descendant of this screen's
/// BlocProvider (it attaches to the Navigator's Overlay), so the same Bloc
/// instance must be forwarded explicitly. Shared by the header badge button
/// and the pending-approvals section's "See all" link.
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
      // No create-agent mutation exists on the backend yet: say so, don't fake it.
      floatingActionButton: SeenExtendedFab(
        label: l10n.agentsAddAction,
        onPressed: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.agentsAddSoon))),
      ),
      body: SeenScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              SeenScreenHeader(
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
              Expanded(
                child: BlocBuilder<AgentsBloc, AgentsState>(
                  builder: (context, state) => switch (state) {
                    AgentsInitial() || AgentsLoading() => const Center(child: SeenLoader()),
                    AgentsFailure(:final message) => _ErrorView(message: message),
                    AgentsLoaded() => _LoadedView(state: state),
                  },
                ),
              ),
            ],
          ),
        ),
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

/// Quick preview cap on the list screen: the full, unbounded list lives on
/// [SubAgentApprovalScreen] behind the "See all" link and the header badge.
const _pendingPreviewLimit = 3;

enum _AgentFilter { all, active, suspended }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state});

  final AgentsLoaded state;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  // Owned here, disposed in dispose(). Search and filter are local,
  // presentation-only refinements of the already loaded directory.
  final _search = TextEditingController();
  _AgentFilter _filter = _AgentFilter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final state = widget.state;
    final preview = state.pendingRequests.take(_pendingPreviewLimit).toList();
    final all = state.subAgents;
    final activeCount = all.where((a) => a.isActive).length;
    final distributed = all.fold<int>(0, (sum, a) => sum + a.balanceCents) / 100;
    final needle = _query.trim().toLowerCase();
    final visible = all.where((a) {
      final byFilter = switch (_filter) {
        _AgentFilter.all => true,
        _AgentFilter.active => a.isActive,
        _AgentFilter.suspended => !a.isActive,
      };
      return byFilter &&
          (needle.isEmpty || a.name.toLowerCase().contains(needle) || a.code.toLowerCase().contains(needle));
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<AgentsBloc>()..add(const AgentsLoadRequested());
        await bloc.stream.firstWhere((x) => x is! AgentsLoading);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: SeenStatCard(label: l10n.agentsStatActive, value: s.numeral(activeCount), dotColor: c.successFg),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(
                child: SeenStatCard(
                  label: l10n.agentsStatDistributed,
                  value: SeenFormat.isolate(SeenFormat.money(distributed)),
                  dotColor: c.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: SeenSpace.s4),
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
          SeenSearchField(
            hint: l10n.agentsSearchHint,
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: SeenSpace.s3),
          SeenSegmentedControl(
            labels: [l10n.walletFilterAll, l10n.agentsFilterActive, l10n.agentsFilterSuspended],
            selectedIndex: _AgentFilter.values.indexOf(_filter),
            onSelected: (i) => setState(() => _filter = _AgentFilter.values[i]),
          ),
          const SizedBox(height: SeenSpace.s4),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l10n.agentsNoMatch, style: t.body.copyWith(color: c.inkMuted))),
            )
          else
            for (final agent in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                child: SeenSubAgentCard(
                  name: agent.name,
                  code: agent.code,
                  balance: agent.balanceCents / 100,
                  suspended: !agent.isActive,
                  statusLabel: agent.isActive ? l10n.agentsFilterActive : l10n.agentsStatusSuspended,
                  balanceLabel: s.balance,
                  fundLabel: l10n.subAgentFundAction,
                  onFund: () => showFundSubAgentSheet(
                    context,
                    subAgent: agent,
                    masterAvailableBalanceCents: state.masterWalletBalance?.availableCents ?? 0,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
