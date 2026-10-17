import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/new_sub_agent.dart';
import '../../domain/entities/sub_agent.dart';
import '../bloc/sub_agent_management_bloc.dart';

/// Edit credit limit (Figma AGT-02). Resolves to `true` when the limit was
/// saved. [masterAvailableCents] is the ceiling the master agent may grant
/// (null while unknown: the server stays the authority).
Future<bool?> showEditCreditLimitSheet(
  BuildContext context, {
  required SubAgent subAgent,
  required int? masterAvailableCents,
  CreditLimitBloc Function()? createBloc,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) =>
          (createBloc ?? InjectionContainer.instance.createCreditLimitBloc)(),
      child: EditCreditLimitSheet(
          subAgent: subAgent, masterAvailableCents: masterAvailableCents),
    ),
  );
}

class EditCreditLimitSheet extends StatefulWidget {
  const EditCreditLimitSheet(
      {super.key, required this.subAgent, required this.masterAvailableCents});

  final SubAgent subAgent;
  final int? masterAvailableCents;

  @override
  State<EditCreditLimitSheet> createState() => _EditCreditLimitSheetState();
}

class _EditCreditLimitSheetState extends State<EditCreditLimitSheet> {
  // Owned here, disposed in dispose().
  late final _limit = TextEditingController(
    text: widget.subAgent.creditLimitCents == null
        ? ''
        : MoneyParser.decimalStringFromCents(widget.subAgent.creditLimitCents!),
  );

  @override
  void initState() {
    super.initState();
    _limit.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  int? get _cents {
    final text = _limit.text.trim();
    if (text.isEmpty) return null;
    try {
      final v = MoneyParser.centsFromDecimalString(text);
      return v >= 0 ? v : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final agent = widget.subAgent;
    final used = agent.creditUsedCents;
    final max = widget.masterAvailableCents;
    final cents = _cents;

    return BlocConsumer<CreditLimitBloc, CreditLimitState>(
      listenWhen: (previous, current) => current.updated != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.agentCreditSaved)));
        Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final issue = state.issue;
        final belowUsage = (cents != null && used != null && cents < used) ||
            issue?.kind == SubAgentIssueKind.limitBelowUsage;
        final usedForMessage = issue?.amountCents ?? used;
        final aboveBalance = (cents != null && max != null && cents > max) ||
            issue?.kind == SubAgentIssueKind.limitAboveAllowed;
        final maxForMessage = issue?.kind == SubAgentIssueKind.limitAboveAllowed
            ? issue?.amountCents
            : max;
        final changed = cents != null && cents != agent.creditLimitCents;
        final valid = changed && !belowUsage && !aboveBalance;
        String? error;
        if (belowUsage && usedForMessage != null) {
          error =
              l10n.agentCreditBelowUsage(SeenFormat.usd(usedForMessage / 100));
        } else if (aboveBalance && maxForMessage != null) {
          error = l10n.agentCreditAboveBalanceError(
              SeenFormat.usd(maxForMessage / 100));
        }

        Widget tile(String label, int? value) => Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                    color: SeenBrand.violet05,
                    borderRadius: BorderRadius.all(SeenRadius.r14)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.caption.copyWith(color: c.inkMuted)),
                      Text(value == null ? '—' : SeenFormat.usd(value / 100),
                          style: t.bodyStrong),
                    ],
                  ),
                ),
              ),
            );

        return SeenSheet(
          title: l10n.agentCreditTitle,
          subtitle: agent.name,
          footer: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: valid ? 1 : 0.45,
                  child: SeenButton(
                    label:
                        state.submitting ? l10n.loading : l10n.agentCreditSave,
                    loading: state.submitting,
                    expand: true,
                    onPressed: (!valid || state.submitting)
                        ? null
                        : () => context.read<CreditLimitBloc>().add(
                            CreditLimitSubmitted(
                                subAgentId: agent.id, limitCents: cents)),
                  ),
                ),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(
                child: SeenButton.secondary(
                  label: l10n.transferCancel,
                  expand: true,
                  onPressed: state.submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  tile(l10n.agentCreditCurrent, agent.creditLimitCents),
                  const SizedBox(width: 8),
                  tile(l10n.agentCreditUsed, used),
                ],
              ),
              const SizedBox(height: 14),
              SeenTextField(
                label: l10n.agentCreditNew,
                controller: _limit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [LatinDigitsFormatter()],
                mono: true,
                ltr: true,
                suffixText: 'USD',
                errorText: error,
                onChanged: (_) {},
              ),
              if (max != null) ...[
                const SizedBox(height: 14),
                SeenInlineBanner(
                  tone: SeenBannerTone.warn,
                  message:
                      l10n.agentCreditAboveBalance(SeenFormat.usd(max / 100)),
                ),
              ],
              if (issue != null &&
                  issue.kind != SubAgentIssueKind.limitBelowUsage &&
                  issue.kind != SubAgentIssueKind.limitAboveAllowed) ...[
                const SizedBox(height: 14),
                SeenInlineBanner(
                  tone: issue.kind == SubAgentIssueKind.offline
                      ? SeenBannerTone.offline
                      : SeenBannerTone.error,
                  message: issue.kind == SubAgentIssueKind.offline
                      ? l10n.recoveryOffline
                      : l10n.recoveryServerError,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
