import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/mode_repository_impl.dart';
import '../../domain/entities/app_mode.dart';
import '../../domain/repositories/mode_repository.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/mode_cubit.dart';
import 'agent_face.dart';
import 'agent_tab.dart';
import 'flip_switcher.dart';
import 'manasik_face.dart';
import 'mode_bottom_bar.dart';

/// Dual-mode root: the agent workspace ([agentHome]) and the Manasik hub live
/// on two faces of a 3D flip, switched from the bottom bar. Both faces stay
/// mounted so neither loses state. The last used mode is restored on launch.
class ModeShell extends StatelessWidget {
  const ModeShell({
    super.key,
    required this.agentHome,
    this.repository,
    this.createDashboardCubit,
    this.agentTabs = const [],
    this.onAccount,
  });

  final Widget agentHome;

  /// Tabs shown after "home" while the agent workspace is showing.
  final List<AgentTab> agentTabs;

  /// Opens the account sheet from the hub's account tab.
  final void Function(BuildContext context)? onAccount;

  /// Override for tests.
  final ModeRepository? repository;
  final DashboardCubit Function()? createDashboardCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ModeCubit(repository ?? ModeRepositoryImpl())..restore(),
      child: _ModeShellView(
        agentHome: agentHome,
        agentTabs: agentTabs,
        onAccount: onAccount,
        createDashboardCubit: createDashboardCubit,
      ),
    );
  }
}

class _ModeShellView extends StatefulWidget {
  const _ModeShellView({
    required this.agentHome,
    required this.agentTabs,
    this.onAccount,
    this.createDashboardCubit,
  });

  final Widget agentHome;
  final List<AgentTab> agentTabs;
  final void Function(BuildContext context)? onAccount;
  final DashboardCubit Function()? createDashboardCubit;

  @override
  State<_ModeShellView> createState() => _ModeShellViewState();
}

class _ModeShellViewState extends State<_ModeShellView> {
  /// 0 = home, i = agentTabs[i - 1].
  int _agentIndex = 0;

  void _onAgentTab(BuildContext context, int i) {
    if (i == 0 || i > widget.agentTabs.length) {
      setState(() => _agentIndex = 0);
      return;
    }
    final tab = widget.agentTabs[i - 1];
    if (tab.builder != null) {
      setState(() => _agentIndex = i);
    } else {
      tab.onTap?.call(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModeCubit, ModeState>(
      builder: (context, state) {
        if (!state.restored) return const Scaffold(body: SizedBox.shrink());
        final cubit = context.read<ModeCubit>();
        final agentMode = state.mode == AppMode.agent;
        return PopScope(
          // System back on an agent tab returns to Home instead of leaving.
          canPop: !(agentMode && _agentIndex != 0),
          onPopInvoked: (didPop) {
            if (!didPop) setState(() => _agentIndex = 0);
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: FlipSwitcher(
              flipped: state.mode == AppMode.manasik,
              front: AgentFace(
                home: widget.agentHome,
                tabs: widget.agentTabs,
                index: _agentIndex,
              ),
              back: ManasikFace(
                tab: state.manasikTab,
                createDashboardCubit: widget.createDashboardCubit,
              ),
            ),
            bottomNavigationBar: ModeBottomBar(
              mode: state.mode,
              manasikTab: state.manasikTab,
              agentTabs: widget.agentTabs,
              agentIndex: _agentIndex,
              onAgentTab: (i) => _onAgentTab(context, i),
              onAccount: widget.onAccount,
              onToggleMode: cubit.toggle,
              onManasikTab: cubit.selectManasikTab,
            ),
          ),
        );
      },
    );
  }
}
