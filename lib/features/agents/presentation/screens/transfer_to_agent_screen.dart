import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/failure_message.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/error_patterns.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/loading/seen_blocking_overlay.dart';
import '../../../../core/presentation/widgets/loading/loading_strings.dart';
import '../../domain/entities/sub_agent.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';

/// Transfer to agent (Figma WAL-07 / 07b / 07c): choose a sub-agent, amount with
/// quick chips and an optional note, a confirmation sheet, then the success
/// page. Owns an [AgentsBloc] (sub-agents + the master balance + the funding
/// mutation); the balance on the success page is the refetched one.
class TransferToAgentScreen extends StatelessWidget {
  const TransferToAgentScreen(
      {super.key, this.initialAgentId, this.createBloc});

  /// Pre-selects this sub-agent (e.g. coming from its card).
  final String? initialAgentId;

  /// Test seam; defaults to the DI container.
  final AgentsBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          (createBloc ?? InjectionContainer.instance.createAgentsBloc)()
            ..add(const AgentsLoadRequested()),
      child: _View(initialAgentId: initialAgentId),
    );
  }
}

class _View extends StatefulWidget {
  const _View({this.initialAgentId});

  final String? initialAgentId;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  static const _chips = [100, 300, 500, 1000];

  // Owned here, disposed in dispose().
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _agentId;
  _Done? _done;

  @override
  void initState() {
    super.initState();
    _agentId = widget.initialAgentId;
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _cents {
    final text = _amount.text.trim();
    if (text.isEmpty) return null;
    try {
      final v = MoneyParser.centsFromDecimalString(text);
      return v > 0 ? v : null;
    } on FormatException {
      return null;
    }
  }

  SubAgent? _selected(List<SubAgent> agents) {
    for (final a in agents) {
      if (a.id == _agentId) return a;
    }
    // A single active agent needs no choosing.
    final active = agents.where((a) => a.isActive && a.canFund).toList();
    return _agentId == null && active.length == 1 ? active.first : null;
  }

  Future<void> _pickAgent(List<SubAgent> agents) async {
    final l10n = AppLocalizations.of(context)!;
    final active = agents.where((a) => a.isActive && a.canFund).toList();
    final picked = await showSeenSheet<SubAgent>(
      context: context,
      title: l10n.transferPickerTitle,
      builder: (sheetContext) => active.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.transferNoAgents, textAlign: TextAlign.center),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AgentCard(
                      agent: a,
                      selected: a.id == _agentId,
                      trailingLabel: l10n.transferPick,
                      onTap: () => Navigator.of(sheetContext).pop(a),
                    ),
                  ),
              ],
            ),
    );
    if (picked != null && mounted) setState(() => _agentId = picked.id);
  }

  Future<void> _review(SubAgent agent, int cents, int? availableCents) {
    final bloc = context.read<AgentsBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BlocProvider.value(
        value: bloc,
        child: _ConfirmSheet(
          agent: agent,
          cents: cents,
          note: _note.text.trim(),
          availableCents: availableCents,
          onSuccess: () {
            if (mounted) {
              setState(() => _done = _Done(agent: agent, cents: cents));
            }
          },
        ),
      ),
    );
  }

  void _another() {
    _amount.clear();
    _note.clear();
    setState(() {
      _done = null;
      _agentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<AgentsBloc, AgentsState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (current is AgentsLoaded &&
              previous is AgentsLoaded &&
              (previous.subAgents != current.subAgents ||
                  previous.masterWalletBalance != current.masterWalletBalance)),
      builder: (context, state) {
        if (_done != null && state is AgentsLoaded) {
          return _SuccessView(
              done: _done!,
              balance: state.masterWalletBalance?.availableCents,
              onAnother: _another);
        }
        return SeenBlockingOverlay(
          visible: state is AgentsLoaded && state.fundingStatus == FundingStatus.submitting,
          title: SeenStrings.of(context).submittingTransfer,
          child: Scaffold(
          body: SeenScreenBackground(
            washHeight: 320,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(title: l10n.walletTransferToAgent),
                  Expanded(
                    child: switch (state) {
                      AgentsLoaded() => _Form(
                          state: state,
                          agent: _selected(state.subAgents),
                          amount: _amount,
                          note: _note,
                          cents: _cents,
                          chips: _chips,
                          onChange: () => _pickAgent(state.subAgents),
                          onChip: (v) => _amount.text = '$v.00',
                          onReview: _review,
                        ),
                      AgentsFailure() => ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          children: [
                            SeenInlineBanner(
                              tone: SeenBannerTone.error,
                              message: state.message,
                              actionLabel: l10n.recoveryRetry,
                              onAction: () => context
                                  .read<AgentsBloc>()
                                  .add(const AgentsLoadRequested()),
                            ),
                          ],
                        ),
                      _ => SeenWaitPolicy.loading(
                        loading: SeenCardsSkeleton(count: 2, label: SeenStrings.of(context).loadingLabel),
                        onRetry: () => context.read<AgentsBloc>().add(const AgentsLoadRequested()),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _Done {
  const _Done({required this.agent, required this.cents});

  final SubAgent agent;
  final int cents;
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.agent,
    required this.amount,
    required this.note,
    required this.cents,
    required this.chips,
    required this.onChange,
    required this.onChip,
    required this.onReview,
  });

  final AgentsLoaded state;
  final SubAgent? agent;
  final TextEditingController amount;
  final TextEditingController note;
  final int? cents;
  final List<int> chips;
  final VoidCallback onChange;
  final ValueChanged<int> onChip;
  final Future<void> Function(SubAgent agent, int cents, int? available)
      onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = SeenType.of(context);
    final available = state.masterWalletBalance?.availableCents;
    final insufficient =
        cents != null && available != null && cents! > available;
    final valid = agent != null && cents != null && !insufficient;
    const gap = SizedBox(height: 14);
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(l10n.transferToLabel, style: t.label),
              const SizedBox(height: 14),
              agent != null
                  ? _AgentCard(
                      agent: agent!,
                      selected: true,
                      trailingLabel: l10n.transferChange,
                      onTap: onChange)
                  : _ChooseCard(
                      label: l10n.transferChoose,
                      action: l10n.transferPick,
                      onTap: onChange),
              gap,
              SeenTextField(
                label: l10n.transferAmountLabel,
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  const LatinDigitsFormatter(),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                mono: true,
                ltr: true,
                suffixText: 'USD',
                helper: available == null
                    ? null
                    : l10n.transferAvailable(SeenFormat.usd(available / 100)),
              ),
              gap,
              Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _AmountChip(
                        value: chips[i],
                        selected: cents == chips[i] * 100,
                        onTap: () => onChip(chips[i]),
                      ),
                    ),
                  ],
                ],
              ),
              gap,
              SeenTextField(
                label: l10n.transferNoteLabel,
                controller: note,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
              ),
              if (insufficient) ...[
                gap,
                SeenInlineBanner(
                  tone: SeenBannerTone.error,
                  message: l10n.transferInsufficient(
                    SeenFormat.usd(available / 100),
                    SeenFormat.usd(cents! / 100),
                  ),
                ),
              ],
            ],
          ),
        ),
        SeenActionBar(
          actions: [
            SeenButton(
              label: l10n.transferReview,
              expand: true,
              onPressed:
                  valid ? () => onReview(agent!, cents!, available) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard(
      {required this.agent,
      required this.selected,
      required this.trailingLabel,
      required this.onTap});

  final SubAgent agent;
  final bool selected;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final initial =
        agent.name.trim().isEmpty ? '?' : agent.name.trim().characters.first;
    return Semantics(
      button: true,
      label: agent.name,
      excludeSemantics: true,
      child: Material(
        color: SeenBrand.violet05,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r18),
          side: BorderSide(color: selected ? SeenBrand.violet : c.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(SeenRadius.r18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                      color: SeenBrand.violet10, shape: BoxShape.circle),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                        child: Text(initial,
                            style: t.label.copyWith(color: SeenBrand.violet))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name, style: t.label),
                      Text(
                        l10n.transferAgentMeta(
                            agent.balanceKnown ? SeenFormat.usd(agent.balanceCents / 100) : '—'),
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                Text(trailingLabel,
                    style: t.label.copyWith(color: c.primaryInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooseCard extends StatelessWidget {
  const _ChooseCard(
      {required this.label, required this.action, required this.onTap});

  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r18),
          side: BorderSide(color: c.borderStrong),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(SeenRadius.r18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: t.label.copyWith(color: c.inkSecondary))),
                Text(action, style: t.label.copyWith(color: c.primaryInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(
      {required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final label = value >= 1000
        ? '${value ~/ 1000},${(value % 1000).toString().padLeft(3, '0')}'
        : '$value';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? SeenBrand.violet10 : c.card,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? SeenBrand.violet : c.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 38,
            child: Center(
              child: Text(label,
                  style: t.label.copyWith(
                      color: selected ? SeenBrand.violet : c.inkSecondary)),
            ),
          ),
        ),
      ),
    );
  }
}

/// WAL-07b: the confirmation bottom sheet. Submitting runs through the
/// ancestor [AgentsBloc]; success closes the sheet and tells the screen.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.agent,
    required this.cents,
    required this.note,
    required this.availableCents,
    required this.onSuccess,
  });

  final SubAgent agent;
  final int cents;
  final String note;
  final int? availableCents;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: t.body.copyWith(color: c.inkSecondary))),
              Text(value, style: t.bodyStrong),
            ],
          ),
        );
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: (previous, current) =>
          current is AgentsLoaded &&
          current.fundingStatus != FundingStatus.idle,
      listener: (context, state) {
        final loaded = state as AgentsLoaded;
        switch (loaded.fundingStatus) {
          case FundingStatus.success:
            context.read<AgentsBloc>().add(const FundingStatusCleared());
            onSuccess();
            Navigator.of(context).pop();
          case FundingStatus.failure:
            final bloc = context.read<AgentsBloc>()
              ..add(const FundingStatusCleared());
            showSeenErrorSheet(
              context,
              title: l10n.transferFailedTitle,
              detail: [
                if (loaded.fundingError != null) failureTextOr(l10n, loaded.fundingFailure, loaded.fundingError!),
                if (loaded.fundingReference != null)
                  l10n.errorReference(loaded.fundingReference!),
              ].join(' · '),
              retryLabel: l10n.errorTryAgain,
              cancelLabel: l10n.errorCancel,
            ).then((retry) {
              if (retry) {
                bloc.add(SubAgentWalletFundingSubmitted(
                  subAgentId: agent.id,
                  amountCents: cents,
                  note: note.isEmpty ? null : note,
                ));
              }
            });
          case FundingStatus.idle:
          case FundingStatus.submitting:
            break;
        }
      },
      child: SeenSheet(
        title: l10n.transferConfirmTitle,
        footer: BlocBuilder<AgentsBloc, AgentsState>(
          buildWhen: (previous, current) =>
              current is AgentsLoaded &&
              (previous is! AgentsLoaded ||
                  previous.fundingStatus != current.fundingStatus),
          builder: (context, state) {
            final submitting = state is AgentsLoaded &&
                state.fundingStatus == FundingStatus.submitting;
            return Row(
              children: [
                Expanded(
                  child: SeenButton(
                    label: submitting ? l10n.loading : l10n.transferConfirm,
                    loading: submitting,
                    expand: true,
                    onPressed: submitting
                        ? null
                        : () => context
                            .read<AgentsBloc>()
                            .add(SubAgentWalletFundingSubmitted(
                              subAgentId: agent.id,
                              amountCents: cents,
                              note: note.isEmpty ? null : note,
                            )),
                  ),
                ),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: SeenButton.secondary(
                    label: l10n.transferCancel,
                    expand: true,
                    onPressed:
                        submitting ? null : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(SeenRadius.r22),
                border: Border.all(color: c.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                  children: [
                    row(l10n.transferRowTo, agent.name),
                    row(l10n.transferRowAmount, SeenFormat.usd(cents / 100)),
                    if (availableCents != null)
                      row(l10n.transferRowMyAfter,
                          SeenFormat.usd((availableCents! - cents) / 100)),
                    row(l10n.transferRowAgentAfter,
                        agent.balanceKnown ? SeenFormat.usd((agent.balanceCents + cents) / 100) : '—'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.transferIrreversible,
                  style: t.caption.copyWith(color: c.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// WAL-07c: success. The balance shown is the refetched one (never computed).
class _SuccessView extends StatelessWidget {
  const _SuccessView(
      {required this.done, required this.balance, required this.onAnother});

  final _Done done;
  final int? balance;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final ok = SeenRequestStatus.completed.colors;
    return Scaffold(
      body: SeenScreenBackground(
        washHeight: 320,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: ok.bg,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border)),
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius:
                                      const BorderRadius.all(SeenRadius.r20),
                                  boxShadow: SeenShadows.stickyBar,
                                ),
                                child: const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(
                                      child: SeenSvgIcon(SeenVectors.notifCheck,
                                          size: 36)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(l10n.transferDoneTitle,
                          textAlign: TextAlign.center, style: t.h1),
                      const SizedBox(height: 12),
                      Text(
                        l10n.transferDoneBody(
                            SeenFormat.usd(done.cents / 100), done.agent.name),
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: c.inkSecondary),
                      ),
                      if (balance != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: Text(l10n.transferRowBalanceNow,
                                    style: t.body
                                        .copyWith(color: c.inkSecondary))),
                            Text(SeenFormat.usd(balance! / 100),
                                style: t.bodyStrong),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SeenActionBar(
              actions: [
                SeenButton(
                  label: l10n.transferBackToWallet,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                SeenButton.secondary(
                    label: l10n.transferAnother,
                    expand: true,
                    onPressed: onAnother),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
