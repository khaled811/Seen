import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import 'method_selector.dart';
import 'wallet_labels.dart';

/// Shows the sheet, wired to the ancestor [WalletBloc]. The caller (the
/// wallet screen) owns the [WalletBloc] provider; this just reads it.
///
/// Built directly from [SeenSheet] rather than the `showSeenSheet()` helper:
/// that helper builds its `footer` and `child` from two separate callbacks
/// that don't share an ancestor, so a `BlocProvider.value` wrapped around
/// just one of them wouldn't reach the other — the footer's submit button
/// needs the same [WalletBloc] the form body does.
Future<void> showTopUpRequestSheet(BuildContext context) {
  final walletBloc = context.read<WalletBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => BlocProvider.value(
      value: walletBloc,
      child: const TopUpRequestSheet(),
    ),
  );
}

class TopUpRequestSheet extends StatefulWidget {
  const TopUpRequestSheet({super.key});

  @override
  State<TopUpRequestSheet> createState() => _TopUpRequestSheetState();
}

class _TopUpRequestSheetState extends State<TopUpRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  TopUpMethod _method = TopUpMethod.bankTransfer;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<WalletBloc>().add(
          WalletTopUpSubmitted(
            amountCents: MoneyParser.centsFromDecimalString(_amountController.text.trim()),
            method: _method,
            referenceNumber: _referenceController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          current is WalletLoaded && current.topUpStatus != TopUpSubmissionStatus.idle,
      listener: (context, state) {
        final loaded = state as WalletLoaded;
        switch (loaded.topUpStatus) {
          case TopUpSubmissionStatus.success:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.topUpSuccessMessage)));
            context.read<WalletBloc>().add(const WalletTopUpStatusCleared());
            Navigator.of(context).pop();
          case TopUpSubmissionStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(loaded.topUpError ?? l10n.error)));
            context.read<WalletBloc>().add(const WalletTopUpStatusCleared());
          case TopUpSubmissionStatus.idle:
          case TopUpSubmissionStatus.submitting:
            break;
        }
      },
      child: SeenSheet(
        title: l10n.topUpSheetTitle,
        footer: BlocBuilder<WalletBloc, WalletState>(
          buildWhen: (previous, current) =>
              current is WalletLoaded &&
              (previous is! WalletLoaded || previous.topUpStatus != current.topUpStatus),
          builder: (context, state) {
            final isSubmitting =
                state is WalletLoaded && state.topUpStatus == TopUpSubmissionStatus.submitting;
            return SeenButton(
              label: isSubmitting ? l10n.loading : l10n.submit,
              expand: true,
              onPressed: isSubmitting ? null : _submit,
            );
          },
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SeenTextField(
                label: l10n.topUpAmountLabel,
                isRequired: true,
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                mono: true,
                ltr: true,
                suffixText: 'USD',
                validator: (value) =>
                    FormValidators.positiveAmount(value, message: l10n.validationInvalidAmount),
              ),
              const SizedBox(height: SeenSpace.s4),
              Text(l10n.topUpPaymentMethodLabel, style: text.bodyMedium),
              const SizedBox(height: SeenSpace.s2),
              SeenMethodSelector<TopUpMethod>(
                value: _method,
                onChanged: (value) => setState(() => _method = value),
                options: [
                  SeenMethodOption(
                    value: TopUpMethod.bankTransfer,
                    icon: SeenIcons.bank,
                    label: WalletLabels.topUpMethod(l10n, TopUpMethod.bankTransfer),
                    caption: l10n.topUpMethodBankTransferCaption,
                  ),
                  SeenMethodOption(
                    value: TopUpMethod.cash,
                    icon: SeenIcons.cash,
                    label: WalletLabels.topUpMethod(l10n, TopUpMethod.cash),
                    caption: l10n.topUpMethodCashCaption,
                  ),
                  SeenMethodOption(
                    value: TopUpMethod.exchangeHouse,
                    icon: SeenIcons.exchange,
                    label: WalletLabels.topUpMethod(l10n, TopUpMethod.exchangeHouse),
                    caption: l10n.topUpMethodExchangeHouseCaption,
                  ),
                ],
              ),
              const SizedBox(height: SeenSpace.s4),
              SeenTextField(
                label: l10n.topUpReferenceNumberLabel,
                isRequired: true,
                controller: _referenceController,
                mono: true,
                ltr: true,
                validator: (value) => FormValidators.required(value, message: l10n.validationRequired),
              ),
              const SizedBox(height: SeenSpace.s4),
              // Notes stays a plain multi-line field — SeenTextField is a
              // fixed single-line 52px control with no multiline variant.
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.topUpNotesLabel),
              ),
              const SizedBox(height: SeenSpace.s4),
              // Receipt upload is mocked/decoupled until the backend's
              // Supabase mutations are active (per Task 06) — shown,
              // disabled, so the affordance reads as "coming soon" rather
              // than silently missing.
              Row(children: [
                Icon(SeenIcons.file, size: 20, color: c.inkMuted),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.topUpReceiptLabel, style: text.bodyMedium!.copyWith(color: c.inkMuted)),
                      Text(l10n.topUpReceiptComingSoon, style: text.labelSmall),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
