import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validators/form_validators.dart';
import '../../domain/entities/sub_agent.dart';
import '../bloc/reclaim_cubit.dart';

/// Takes money back from a sub-agency into the main agent's wallet (`reclaimFromSubAgent`).
/// Resolves to true when the money moved (the caller reads the balances again).
/// Resolves the amount (cents) taken back, or null when the sheet was closed without it.
Future<int?> showReclaimSubAgentSheet(BuildContext context, {required SubAgent subAgent, ReclaimCubit Function()? createCubit}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReclaimSubAgentSheet(subAgent: subAgent, createCubit: createCubit),
  );
}

class ReclaimSubAgentSheet extends StatefulWidget {
  const ReclaimSubAgentSheet({super.key, required this.subAgent, this.createCubit});

  final SubAgent subAgent;

  /// Test seam; defaults to the DI container.
  final ReclaimCubit Function()? createCubit;

  @override
  State<ReclaimSubAgentSheet> createState() => _ReclaimSubAgentSheetState();
}

class _ReclaimSubAgentSheetState extends State<ReclaimSubAgentSheet> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  /// What the last send carried: handed back when the sheet closes on success.
  int? _sentCents;
  late final ReclaimCubit _cubit = (widget.createCubit ?? () => InjectionContainer.instance.createReclaimCubit(widget.subAgent.id))();

  @override
  void dispose() {
    _cubit.close();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _sentCents = MoneyParser.centsFromDecimalString(_amount.text.trim());
    _cubit.submit(amountCents: _sentCents!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final max = widget.subAgent.balanceCents;
    return BlocListener<ReclaimCubit, ReclaimState>(
      bloc: _cubit,
      listenWhen: (p, n) => p.status != n.status,
      listener: (context, state) {
        if (state.status == ReclaimStatus.done) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(s.reclaimDone)));
          Navigator.of(context).pop(_sentCents);
        } else if (state.status == ReclaimStatus.failed) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failureTextOr(l10n, state.failure, l10n.error))));
        }
      },
      child: SeenSheet(
        title: s.reclaimTitle,
        subtitle: s.reclaimAvailable(widget.subAgent.name, SeenFormat.usd(max / 100)),
        footer: BlocBuilder<ReclaimCubit, ReclaimState>(
          bloc: _cubit,
          builder: (context, state) {
            final busy = state.status == ReclaimStatus.submitting;
            return SeenButton(label: busy ? l10n.loading : s.reclaimAction, expand: true, loading: busy, onPressed: busy ? null : _submit);
          },
        ),
        child: Form(
          key: _formKey,
          child: SeenTextField(
            label: l10n.fundAmountLabel,
            isRequired: true,
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            mono: true,
            ltr: true,
            suffixText: 'USD',
            validator: (value) =>
                FormValidators.positiveAmount(value, message: l10n.validationInvalidAmount) ??
                FormValidators.maxAmount(value, maxCents: max, message: l10n.validationInvalidMaxAmount(SeenFormat.usd(max / 100))),
          ),
        ),
      ),
    );
  }
}
