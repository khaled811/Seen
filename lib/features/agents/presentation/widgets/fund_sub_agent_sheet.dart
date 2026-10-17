import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validators/form_validators.dart';
import '../../domain/entities/sub_agent.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';

/// Shows the sheet, wired to the ancestor [AgentsBloc]. The caller (the
/// sub-agents list screen) owns the [AgentsBloc] provider; this just reads
/// it and forwards it into the sheet's own subtree — a bottom sheet is
/// rendered through the Navigator's Overlay too, so it isn't a descendant
/// of the calling screen's `BlocProvider` any more than a pushed route is.
///
/// Built directly from [SeenSheet] rather than the `showSeenSheet()` helper:
/// that helper's `footer`/`child` callbacks don't share a `BuildContext`
/// ancestor, so a `BlocProvider.value` wrapped around just one of them
/// wouldn't reach the other — the footer's submit button needs the same
/// [AgentsBloc] the form body does.
Future<void> showFundSubAgentSheet(
  BuildContext context, {
  required SubAgent subAgent,
  required int masterAvailableBalanceCents,
}) {
  final bloc = context.read<AgentsBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => BlocProvider.value(
      value: bloc,
      child: FundSubAgentSheet(
        subAgent: subAgent,
        masterAvailableBalanceCents: masterAvailableBalanceCents,
      ),
    ),
  );
}

class FundSubAgentSheet extends StatefulWidget {
  const FundSubAgentSheet({
    super.key,
    required this.subAgent,
    required this.masterAvailableBalanceCents,
  });

  final SubAgent subAgent;
  final int masterAvailableBalanceCents;

  @override
  State<FundSubAgentSheet> createState() => _FundSubAgentSheetState();
}

class _FundSubAgentSheetState extends State<FundSubAgentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _validAmountCents;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final text = _amountController.text.trim();
    final cents =
        text.isEmpty ? null : MoneyParser.centsFromDecimalString(text);
    final valid = cents != null &&
        cents > 0 &&
        cents <= widget.masterAvailableBalanceCents;
    final next = valid ? cents : null;
    if (next != _validAmountCents) setState(() => _validAmountCents = next);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AgentsBloc>().add(
          SubAgentWalletFundingSubmitted(
            subAgentId: widget.subAgent.id,
            amountCents: MoneyParser.centsFromDecimalString(
                _amountController.text.trim()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: (previous, current) =>
          current is AgentsLoaded &&
          current.fundingStatus != FundingStatus.idle,
      listener: (context, state) {
        final loaded = state as AgentsLoaded;
        switch (loaded.fundingStatus) {
          case FundingStatus.success:
            // The agent's balance after the transfer, as the server reports it.
            final updated =
                loaded.subAgents.where((a) => a.id == widget.subAgent.id);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(updated.isEmpty
                    ? l10n.fundSuccessMessage
                    : l10n.fundDoneMessage(
                        SeenFormat.usd(updated.first.balanceCents / 100))),
              ));
            context.read<AgentsBloc>().add(const FundingStatusCleared());
            Navigator.of(context).pop();
          case FundingStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                  SnackBar(content: Text(loaded.fundingError ?? l10n.error)));
            context.read<AgentsBloc>().add(const FundingStatusCleared());
          case FundingStatus.idle:
          case FundingStatus.submitting:
            break;
        }
      },
      child: SeenSheet(
        title: l10n.fundAgentTitle,
        subtitle: l10n.fundFromMainBalance(
            SeenFormat.usd(widget.masterAvailableBalanceCents / 100)),
        footer: BlocBuilder<AgentsBloc, AgentsState>(
          buildWhen: (previous, current) =>
              current is AgentsLoaded &&
              (previous is! AgentsLoaded ||
                  previous.fundingStatus != current.fundingStatus),
          builder: (context, state) {
            final isSubmitting = state is AgentsLoaded &&
                state.fundingStatus == FundingStatus.submitting;
            final label = isSubmitting
                ? l10n.loading
                : _validAmountCents != null
                    ? l10n.fundSubmitActionNamed(
                        SeenFormat.usd(_validAmountCents! / 100),
                        widget.subAgent.name)
                    : l10n.fundSubmitAction;
            return SeenButton(
              label: label,
              expand: true,
              onPressed: isSubmitting ? null : _submit,
            );
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: SeenTextField(
                label: l10n.fundAmountLabel,
                isRequired: true,
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                mono: true,
                ltr: true,
                suffixText: 'USD',
                validator: (value) {
                  final positiveError = FormValidators.positiveAmount(value,
                      message: l10n.validationInvalidAmount);
                  if (positiveError != null) return positiveError;
                  return FormValidators.maxAmount(
                    value,
                    maxCents: widget.masterAvailableBalanceCents,
                    message: l10n.validationInvalidMaxAmount(SeenFormat.usd(
                        widget.masterAvailableBalanceCents / 100)),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (i, v) in const [250, 500, 1000].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAmountChip(
                      value: v,
                      onTap: () => _amountController.text = '$v.00',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({required this.value, required this.onTap});

  final int value;
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
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 36,
            child: Center(
                child: Text(label,
                    style: t.label.copyWith(color: c.inkSecondary))),
          ),
        ),
      ),
    );
  }
}
