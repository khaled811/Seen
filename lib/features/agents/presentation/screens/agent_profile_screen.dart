import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/error_patterns.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../requests/presentation/widgets/request_status_seen_mapping.dart';
import '../../domain/entities/sub_agent.dart';
import '../../domain/entities/sub_agent_profile.dart';
import '../bloc/agent_profile_bloc.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_state.dart';
import '../widgets/edit_credit_limit_sheet.dart';
import '../widgets/fund_sub_agent_sheet.dart';

/// Agent profile (Figma AGT-04): the agent card, balance / limit / monthly
/// requests, Fund · Edit limit · Suspend, the balance history and the agent's
/// requests. Needs the list's [AgentsBloc] above it (the fund sheet uses it).
/// Owns an [AgentProfileBloc].
class AgentProfileScreen extends StatelessWidget {
  const AgentProfileScreen(
      {super.key, required this.subAgent, this.createBloc});

  /// What the list already knows; shown while the profile loads.
  final SubAgent subAgent;

  /// Test seam; defaults to the DI container.
  final AgentProfileBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          (createBloc ?? InjectionContainer.instance.createAgentProfileBloc)()
            ..add(AgentProfileLoadRequested(subAgent.id)),
      child: _View(initial: subAgent),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.initial});

  final SubAgent initial;

  int? _masterAvailable(BuildContext context) {
    final state = context.read<AgentsBloc>().state;
    return state is AgentsLoaded
        ? state.masterWalletBalance?.availableCents
        : null;
  }

  Future<void> _fund(BuildContext context, SubAgent agent) async {
    final bloc = context.read<AgentProfileBloc>();
    await showFundSubAgentSheet(
      context,
      subAgent: agent,
      masterAvailableBalanceCents: _masterAvailable(context) ?? 0,
    );
    bloc.add(AgentProfileLoadRequested(agent.id));
  }

  Future<void> _editLimit(BuildContext context, SubAgent agent) async {
    final bloc = context.read<AgentProfileBloc>();
    final saved = await showEditCreditLimitSheet(
      context,
      subAgent: agent,
      masterAvailableCents: _masterAvailable(context),
    );
    if (saved == true) bloc.add(AgentProfileLoadRequested(agent.id));
  }

  Future<void> _toggleActive(
      BuildContext context, SubAgentProfile profile) async {
    final bloc = context.read<AgentProfileBloc>();
    final reactivating = !profile.agent.isActive;
    final reason = await showAgentActiveDialog(
      context,
      reactivate: reactivating,
      inProgressCount: profile.inProgressRequestCount,
    );
    if (reason == null) return;
    bloc.add(AgentActiveChangeSubmitted(active: reactivating, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AgentProfileBloc, AgentProfileState>(
      listenWhen: (previous, current) =>
          previous.outcomeSeq != current.outcomeSeq && current.outcome != null,
      listener: (context, state) {
        final message = switch (state.outcome!) {
          AgentProfileOutcome.suspended => l10n.agentSuspendedDone,
          AgentProfileOutcome.reactivated => l10n.agentReactivatedDone,
          AgentProfileOutcome.failed => l10n.recoveryServerError,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        final profile = state.profile;
        return Scaffold(
          body: SeenScreenBackground(
            washHeight: 320,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(title: l10n.agentProfileTitle),
                  Expanded(
                    child: switch (state.status) {
                      AgentProfileStatus.loading =>
                        const Center(child: SeenLoader()),
                      AgentProfileStatus.failed => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SeenInlineError(
                              title: l10n.errorSectionLoad,
                              retryLabel: l10n.retry,
                              onRetry: () => context
                                  .read<AgentProfileBloc>()
                                  .add(AgentProfileLoadRequested(initial.id)),
                            ),
                          ),
                        ),
                      AgentProfileStatus.ready => _Body(
                          profile: profile!,
                          busy: state.busy,
                          onFund: () => _fund(context, profile.agent),
                          onEditLimit: () => _editLimit(context, profile.agent),
                          onToggleActive: () => _toggleActive(context, profile),
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.profile,
    required this.busy,
    required this.onFund,
    required this.onEditLimit,
    required this.onToggleActive,
  });

  final SubAgentProfile profile;
  final bool busy;
  final VoidCallback onFund;
  final VoidCallback onEditLimit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final agent = profile.agent;
    final chip = agent.invitePending
        ? (SeenRequestStatus.underReview, l10n.agentAddPending)
        : agent.isActive
            ? (SeenRequestStatus.completed, l10n.agentsFilterActive)
            : (SeenRequestStatus.cancelled, l10n.agentsStatusSuspended);
    final meta = [
      if (profile.city != null) profile.city!,
      if (profile.memberSince != null)
        l10n.agentProfileSince(s.monthYear(profile.memberSince!)),
    ].join(' · ');
    final initial = agent.name.trim().isEmpty
        ? ''
        : String.fromCharCodes(agent.name.trim().runes.take(1));

    Widget stat(String label, String value) => Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
                color: SeenBrand.violet05,
                borderRadius: BorderRadius.all(SeenRadius.r14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.inkMuted)),
                  Text(value,
                      maxLines: 1,
                      style: t.bodyStrong
                          .copyWith(fontFeatures: SeenFonts.tabular)),
                ],
              ),
            ),
          ),
        );

    Widget action(String label, VoidCallback? onTap,
            {SeenStatusColors? tone}) =>
        Expanded(
          child: Semantics(
            button: true,
            label: label,
            enabled: onTap != null,
            excludeSemantics: true,
            child: Material(
              color: tone?.bg ?? SeenBrand.violet10,
              borderRadius: const BorderRadius.all(SeenRadius.r14),
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.all(SeenRadius.r14),
                child: SizedBox(
                  height: 40,
                  child: Center(
                      child: Text(label,
                          style: t.label
                              .copyWith(color: tone?.fg ?? SeenBrand.violet))),
                ),
              ),
            ),
          ),
        );

    final suspendTone = agent.isActive
        ? SeenRequestStatus.rejected.colors
        : SeenRequestStatus.completed.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Head card
        ClipRRect(
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
                colors: [Color(0xFFEDE7FE), Colors.white],
              ),
              border: Border.all(color: c.border),
              borderRadius: const BorderRadius.all(SeenRadius.r22),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ExcludeSemantics(
                      child:
                          SeenSvgIcon(SeenVectors.patternGridPromo, size: 160)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                            color: SeenBrand.violet10, shape: BoxShape.circle),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                              child: Text(initial,
                                  style: t.label
                                      .copyWith(color: SeenBrand.violet))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agent.name, style: t.title),
                            if (meta.isNotEmpty)
                              Text(meta,
                                  style: t.caption.copyWith(color: c.inkMuted)),
                            const SizedBox(height: 4),
                            SeenStatusChip(status: chip.$1, label: chip.$2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat(l10n.agentProfileBalance,
                SeenFormat.usd(agent.balanceCents / 100)),
            const SizedBox(width: 8),
            stat(
                l10n.agentAddCreditLimit,
                agent.creditLimitCents == null
                    ? '—'
                    : SeenFormat.usd(agent.creditLimitCents! / 100)),
            const SizedBox(width: 8),
            stat(
              l10n.agentProfileMonthly,
              profile.monthlyRequestCount == null
                  ? '—'
                  : s.numeral(profile.monthlyRequestCount!),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            action(
                agent.isActive
                    ? l10n.agentProfileSuspend
                    : l10n.agentProfileReactivate,
                busy ? null : onToggleActive,
                tone: suspendTone),
            const SizedBox(width: 8),
            action(l10n.agentProfileEditLimit, busy ? null : onEditLimit),
            const SizedBox(width: 8),
            action(l10n.agentProfileFund, busy ? null : onFund),
          ],
        ),
        const SizedBox(height: 14),
        Text(l10n.agentProfileLedger, style: t.title),
        const SizedBox(height: 14),
        if (profile.ledger.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.agentProfileLedgerEmpty,
                style: t.body.copyWith(color: c.inkMuted)),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Column(
              children: [
                for (final (i, e) in profile.ledger.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.title, style: t.body)),
                        const SizedBox(width: 8),
                        Text(
                          SeenFormat.signed(e.amountCents / 100,
                              credit: e.isCredit),
                          textDirection: TextDirection.ltr,
                          style: t.label.copyWith(
                            color: (e.isCredit
                                    ? SeenRequestStatus.completed
                                    : SeenRequestStatus.rejected)
                                .colors
                                .fg,
                            fontFeatures: SeenFonts.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
            l10n.agentProfileRequests(
                s.numeral(profile.inProgressRequestCount)),
            style: t.title),
        const SizedBox(height: 14),
        if (profile.requests.isEmpty)
          Text(l10n.agentProfileRequestsEmpty,
              style: t.body.copyWith(color: c.inkMuted))
        else
          for (final r in profile.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestRow(row: r),
            ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.row});

  final AgentRequestRow row;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final status = row.status.toSeenRequestStatus();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r18),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.serviceName, style: t.label),
                  Text(
                    SeenFormat.isolate(row.referenceId),
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SeenStatusChip(status: status, label: s.requestStatus(status)),
          ],
        ),
      ),
    );
  }
}

/// Suspend / reactivate confirmation (Figma AGT-03). Resolves to the reason
/// (empty when reactivating) on confirm, `null` on cancel.
Future<String?> showAgentActiveDialog(
  BuildContext context, {
  required bool reactivate,
  required int inProgressCount,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _ActiveDialog(reactivate: reactivate, inProgressCount: inProgressCount),
  );
}

class _ActiveDialog extends StatefulWidget {
  const _ActiveDialog(
      {required this.reactivate, required this.inProgressCount});

  final bool reactivate;
  final int inProgressCount;

  @override
  State<_ActiveDialog> createState() => _ActiveDialogState();
}

class _ActiveDialogState extends State<_ActiveDialog> {
  // Owned here, disposed in dispose().
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final tone = widget.reactivate
        ? SeenRequestStatus.completed.colors
        : SeenRequestStatus.rejected.colors;
    final canConfirm = widget.reactivate || _reason.text.trim().isNotEmpty;
    final body = widget.reactivate
        ? l10n.agentReactivateBody
        : widget.inProgressCount > 0
            ? l10n.agentSuspendBody(s.numeral(widget.inProgressCount))
            : l10n.agentSuspendBodyNone;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x142C186A), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(
                color: Color(0x385B36DA),
                blurRadius: 48,
                offset: Offset(0, 24)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(17))),
                  child: const SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                        child: SeenSvgIcon(SeenVectors.notifAlert, size: 31)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.reactivate
                      ? l10n.agentReactivateTitle
                      : l10n.agentSuspendTitle,
                  textAlign: TextAlign.center,
                  style: t.h2,
                ),
                const SizedBox(height: 12),
                Text(body,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: c.inkSecondary)),
                if (!widget.reactivate) ...[
                  const SizedBox(height: 12),
                  SeenTextField(
                      label: l10n.agentSuspendReason, controller: _reason),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: canConfirm ? 1 : 0.45,
                        child: Semantics(
                          button: true,
                          enabled: canConfirm,
                          label: widget.reactivate
                              ? l10n.agentReactivateConfirm
                              : l10n.agentSuspendConfirm,
                          excludeSemantics: true,
                          child: Material(
                            color: tone.bg,
                            borderRadius: const BorderRadius.all(SeenRadius.lg),
                            child: InkWell(
                              onTap: canConfirm
                                  ? () => Navigator.of(context)
                                      .pop(_reason.text.trim())
                                  : null,
                              borderRadius:
                                  const BorderRadius.all(SeenRadius.lg),
                              child: SizedBox(
                                height: 52,
                                child: Center(
                                  child: Text(
                                    widget.reactivate
                                        ? l10n.agentReactivateConfirm
                                        : l10n.agentSuspendConfirm,
                                    style:
                                        t.bodyStrong.copyWith(color: tone.fg),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s3),
                    Expanded(
                      child: SeenButton.outline(
                        label: l10n.transferCancel,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
