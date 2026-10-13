import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/extended_fab.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/search_field.dart';
import '../../../../core/presentation/widgets/segmented_control.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
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

/// Sub-agent network (Figma 13, node 18:722): title with a search button, two
/// overview tiles, an All / Active / Suspended control, the agent cards and an
/// extended "add agent" FAB. A tap on a card opens the fund sheet.
class SubAgentsListScreen extends StatelessWidget {
  const SubAgentsListScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell: no back button.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createAgentsBloc()..add(const AgentsLoadRequested()),
      child: const SubAgentsView(),
    );
  }
}

/// A route pushed via Navigator is not a descendant of this screen's
/// BlocProvider (it attaches to the Navigator's Overlay), so the same Bloc
/// instance must be forwarded explicitly.
void _openApprovals(BuildContext context) {
  final bloc = context.read<AgentsBloc>();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: bloc, child: const SubAgentApprovalScreen()),
    ),
  );
}

/// The screen body, split from [SubAgentsListScreen] so tests can provide
/// their own [AgentsBloc].
class SubAgentsView extends StatefulWidget {
  const SubAgentsView({super.key});

  @override
  State<SubAgentsView> createState() => _SubAgentsViewState();
}

class _SubAgentsViewState extends State<SubAgentsView> {
  // Owned here, disposed in dispose(). The search is a local, presentation-only
  // refinement of the loaded directory, opened by the header's search button.
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
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
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.agentsTitle, style: t.h1)),
                    Semantics(
                      button: true,
                      label: l10n.agentsSearchAction,
                      excludeSemantics: true,
                      child: Material(
                        color: SeenBrand.violet10,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _toggleSearch,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(child: SeenSvgIcon(SeenVectors.agentsSearch, size: 22, color: c.primary)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: SeenSearchField(
                    hint: l10n.agentsSearchHint,
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              Expanded(
                child: BlocBuilder<AgentsBloc, AgentsState>(
                  builder: (context, state) => switch (state) {
                    AgentsInitial() || AgentsLoading() => const Center(child: SeenLoader()),
                    AgentsFailure(:final message) => _ErrorView(message: message),
                    AgentsLoaded() => _LoadedView(state: state, query: _query),
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
/// [SubAgentApprovalScreen] behind the "See all" link.
const _pendingPreviewLimit = 3;

enum _AgentFilter { all, active, suspended }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state, required this.query});

  final AgentsLoaded state;
  final String query;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  _AgentFilter _filter = _AgentFilter.all;

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
    final needle = widget.query.trim().toLowerCase();
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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
        children: [
          // The active-agents tile leads (right in RTL), as in Figma.
          Row(
            children: [
              Expanded(child: SeenAgentStatTile(label: l10n.agentsStatActive, value: s.numeral(activeCount))),
              Expanded(
                child: SeenAgentStatTile(
                  label: l10n.agentsStatDistributed,
                  value: SeenFormat.isolate(SeenFormat.money(distributed)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (preview.isNotEmpty) ...[
            SeenSectionHeader(
              title: l10n.subAgentApprovalsTitle,
              count: state.pendingRequests.length,
              actionLabel: l10n.homeSeeAllAction,
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
            const SizedBox(height: 6),
          ],
          SeenSegmentedControl(
            labels: [l10n.walletFilterAll, l10n.agentsFilterActive, l10n.agentsFilterSuspended],
            selectedIndex: _AgentFilter.values.indexOf(_filter),
            onSelected: (i) => setState(() => _filter = _AgentFilter.values[i]),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l10n.agentsNoMatch, style: t.body.copyWith(color: c.inkMuted))),
            )
          else
            for (final agent in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SeenSubAgentCard(
                  name: agent.name,
                  caption: agent.code,
                  balance: agent.balanceCents / 100,
                  suspended: !agent.isActive,
                  statusLabel: agent.isActive ? l10n.agentsFilterActive : l10n.agentsStatusSuspended,
                  onTap: () => showFundSubAgentSheet(
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
