import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
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
import '../../domain/entities/sub_agent.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';
import 'add_sub_agent_screen.dart';
import 'agent_profile_screen.dart';
import '../widgets/seen_sub_agent_card.dart';

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
      create: (_) => InjectionContainer.instance.createAgentsBloc()
        ..add(const AgentsLoadRequested()),
      child: const SubAgentsView(),
    );
  }
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

  Future<void> _addAgent() async {
    final bloc = context.read<AgentsBloc>();
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddSubAgentScreen()),
    );
    // New agents (and the invite state) come from the server.
    if (added == true) bloc.add(const AgentsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Scaffold(
      floatingActionButton: SeenExtendedFab(
        label: l10n.agentsAddAction,
        onPressed: _addAgent,
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
                            child: Center(
                                child: SeenSvgIcon(SeenVectors.agentsSearch,
                                    size: 22, color: c.primary)),
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
                    AgentsInitial() ||
                    AgentsLoading() =>
                      const Center(child: SeenLoader()),
                    AgentsFailure(:final message) =>
                      _ErrorView(message: message),
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
            onPressed: () =>
                context.read<AgentsBloc>().add(const AgentsLoadRequested()),
          ),
        ],
      ),
    );
  }
}

enum _AgentFilter { all, active, suspended }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state, required this.query});

  final AgentsLoaded state;
  final String query;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  Future<void> _openProfile(SubAgent agent) async {
    final bloc = context.read<AgentsBloc>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
            value: bloc, child: AgentProfileScreen(subAgent: agent)),
      ),
    );
    // The profile may have funded, re-limited or suspended the agent.
    bloc.add(const AgentsLoadRequested());
  }

  _AgentFilter _filter = _AgentFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final state = widget.state;
    final all = state.subAgents;
    final activeCount = all.where((a) => a.isActive).length;
    final distributed =
        all.fold<int>(0, (sum, a) => sum + a.balanceCents) / 100;
    final needle = widget.query.trim().toLowerCase();
    final visible = all.where((a) {
      final byFilter = switch (_filter) {
        _AgentFilter.all => true,
        _AgentFilter.active => a.isActive,
        _AgentFilter.suspended => !a.isActive,
      };
      return byFilter &&
          (needle.isEmpty ||
              a.name.toLowerCase().contains(needle) ||
              a.code.toLowerCase().contains(needle));
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<AgentsBloc>()
          ..add(const AgentsLoadRequested());
        await bloc.stream.firstWhere((x) => x is! AgentsLoading);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
        children: [
          // The active-agents tile leads (right in RTL), as in Figma.
          Row(
            children: [
              Expanded(
                  child: SeenAgentStatTile(
                      label: l10n.agentsStatActive,
                      value: s.numeral(activeCount))),
              Expanded(
                child: SeenAgentStatTile(
                  label: l10n.agentsStatDistributed,
                  value: SeenFormat.isolate(SeenFormat.money(distributed)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SeenSegmentedControl(
            labels: [
              l10n.walletFilterAll,
              l10n.agentsFilterActive,
              l10n.agentsFilterSuspended
            ],
            selectedIndex: _AgentFilter.values.indexOf(_filter),
            onSelected: (i) => setState(() => _filter = _AgentFilter.values[i]),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                  child: Text(l10n.agentsNoMatch,
                      style: t.body.copyWith(color: c.inkMuted))),
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
                  statusLabel: agent.invitePending
                      ? l10n.agentAddPending
                      : (agent.isActive
                          ? l10n.agentsFilterActive
                          : l10n.agentsStatusSuspended),
                  onTap: () => _openProfile(agent),
                ),
              ),
        ],
      ),
    );
  }
}
