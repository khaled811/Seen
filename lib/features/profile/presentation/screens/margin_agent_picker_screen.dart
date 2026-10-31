import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/margin_agents_cubit.dart';
import '../bloc/profile_cubits.dart' show LoadStatus;
import '../widgets/profile_strings.dart';
import 'profit_margin_screen.dart';

/// Margins are set per sub-agency: choose one, then edit its margins (Figma ACC-02).
class MarginAgentPickerScreen extends StatelessWidget {
  const MarginAgentPickerScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final MarginAgentsCubit Function()? createCubit;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const MarginAgentPickerScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createMarginAgentsCubit)()..load(),
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeenScreenHeader(title: s.marginTitle, subtitle: s.marginPickAgent),
                Expanded(
                  child: BlocBuilder<MarginAgentsCubit, MarginAgentsState>(
                    builder: (context, state) {
                      if (state.agents.isEmpty) {
                        return switch (state.status) {
                          LoadStatus.loading => const Center(child: SeenLoader()),
                          LoadStatus.failure => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(failureTextOr(l10n, state.failure, s.loadFailedTitle), textAlign: TextAlign.center),
                                  const SizedBox(height: SeenSpace.s3),
                                  SeenButton(label: s.retry, onPressed: context.read<MarginAgentsCubit>().load),
                                ],
                              ),
                            ),
                          LoadStatus.loaded => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(s.marginNoAgents, textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkMuted)),
                              ),
                            ),
                        };
                      }
                      return RefreshIndicator(
                        onRefresh: context.read<MarginAgentsCubit>().load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: state.agents.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                          itemBuilder: (context, i) {
                            final agent = state.agents[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(agent.name, style: t.label),
                              subtitle: agent.code.isEmpty ? null : Text(agent.code, style: t.caption.copyWith(color: c.inkMuted)),
                              trailing: Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
                              onTap: () => Navigator.of(context).push(ProfitMarginScreen.route(agentId: agent.id, agentName: agent.name)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
