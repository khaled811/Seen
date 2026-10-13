import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/method_selector.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';

/// Figma 12 — full-page top-up request. The wallet screen owns the
/// [WalletBloc]; this route re-provides it with `BlocProvider.value`.
class TopUpRequestScreen extends StatefulWidget {
  const TopUpRequestScreen({super.key, this.bankDetails});

  /// The company account the agent wires money to. The backend does not expose
  /// it yet, so release builds show a "support will send it" note instead of
  /// inventing details; debug builds show an obvious placeholder.
  final TopUpBankDetails? bankDetails;

  static const _debugSample = TopUpBankDetails(
    bankName: 'Sample Bank (debug)',
    accountName: 'Sample Beneficiary',
    iban: 'XX00 0000 0000 0000 0000',
  );

  static Route<void> route(WalletBloc bloc, {TopUpBankDetails? bankDetails}) => MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: bloc, child: TopUpRequestScreen(bankDetails: bankDetails)),
      );

  @override
  State<TopUpRequestScreen> createState() => _TopUpRequestScreenState();
}

class _TopUpRequestScreenState extends State<TopUpRequestScreen> {
  static const _presets = [100, 500, 1000, 5000];

  // Owned here, disposed in dispose().
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
    final notes = _notesController.text.trim();
    context.read<WalletBloc>().add(
          WalletTopUpSubmitted(
            amountCents: MoneyParser.centsFromDecimalString(_amountController.text.trim()),
            method: _method,
            referenceNumber: _referenceController.text.trim(),
            notes: notes.isEmpty ? null : notes,
          ),
        );
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final bank = widget.bankDetails ?? (kDebugMode ? TopUpRequestScreen._debugSample : null);

    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) => current is WalletLoaded && current.topUpStatus != TopUpSubmissionStatus.idle,
      listener: (context, state) {
        final loaded = state as WalletLoaded;
        switch (loaded.topUpStatus) {
          case TopUpSubmissionStatus.success:
            _toast(l10n.topUpSuccessMessage);
            context.read<WalletBloc>().add(const WalletTopUpStatusCleared());
            Navigator.of(context).pop();
          case TopUpSubmissionStatus.failure:
            _toast(loaded.topUpError ?? l10n.error);
            context.read<WalletBloc>().add(const WalletTopUpStatusCleared());
          case TopUpSubmissionStatus.idle:
          case TopUpSubmissionStatus.submitting:
            break;
        }
      },
      child: Scaffold(
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeenScreenHeader(title: l10n.topUpScreenTitle, subtitle: l10n.topUpScreenSubtitle),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 24),
                      children: [
                        Text(l10n.topUpAmountSection, style: t.h2),
                        const SizedBox(height: SeenSpace.s3),
                        SeenTextField(
                          label: l10n.topUpAmountLabel,
                          isRequired: true,
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          mono: true,
                          ltr: true,
                          suffixText: 'USD',
                          validator: (v) => FormValidators.positiveAmount(v, message: l10n.validationInvalidAmount),
                        ),
                        const SizedBox(height: SeenSpace.s2),
                        Wrap(
                          spacing: SeenSpace.s2,
                          runSpacing: SeenSpace.s2,
                          children: [
                            for (final p in _presets)
                              _PresetChip(
                                label: SeenFormat.usd(p),
                                onTap: () => _amountController.text = p.toStringAsFixed(2),
                              ),
                          ],
                        ),
                        const SizedBox(height: SeenSpace.s5),
                        Text(l10n.topUpPaymentMethodLabel, style: t.h2),
                        const SizedBox(height: SeenSpace.s3),
                        SeenMethodSelector<TopUpMethod>(
                          value: _method,
                          onChanged: (v) => setState(() => _method = v),
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
                        if (_method == TopUpMethod.bankTransfer) ...[
                          const SizedBox(height: SeenSpace.s5),
                          Text(l10n.topUpMethodBankTransfer, style: t.h2),
                          const SizedBox(height: SeenSpace.s3),
                          if (bank != null)
                            SeenBankDetailsCard(
                              details: bank,
                              ibanLabel: l10n.topUpIbanLabel,
                              beneficiaryLabel: l10n.topUpBeneficiaryLabel,
                              currencyLabel: l10n.topUpCurrencyLabel,
                              copyLabel: l10n.topUpCopyAction,
                              copiedMessage: l10n.topUpCopiedMessage,
                            )
                          else
                            Text(l10n.topUpBankDetailsUnavailable, style: t.body.copyWith(color: c.inkSecondary)),
                        ],
                        const SizedBox(height: SeenSpace.s5),
                        SeenTextField(
                          label: l10n.topUpReferenceNumberLabel,
                          isRequired: true,
                          controller: _referenceController,
                          mono: true,
                          ltr: true,
                          validator: (v) => FormValidators.required(v, message: l10n.validationRequired),
                        ),
                        const SizedBox(height: SeenSpace.s4),
                        SeenTextField(label: l10n.topUpNotesLabel, controller: _notesController, maxLines: 3),
                        const SizedBox(height: SeenSpace.s5),
                        Text(l10n.topUpReceiptSection, style: t.h2),
                        const SizedBox(height: SeenSpace.s3),
                        // No picker or upload API yet: say so, never fake an attachment.
                        SeenDropzone(
                          title: l10n.topUpReceiptLabel,
                          caption: l10n.topUpReceiptComingSoon,
                          onTap: () => _toast(l10n.topUpReceiptComingSoon),
                        ),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<WalletBloc, WalletState>(
                  buildWhen: (p, c) =>
                      c is WalletLoaded && (p is! WalletLoaded || p.topUpStatus != c.topUpStatus),
                  builder: (context, state) {
                    final submitting = state is WalletLoaded && state.topUpStatus == TopUpSubmissionStatus.submitting;
                    return SeenActionBar(
                      actions: [
                        SeenButton(
                          label: submitting ? l10n.loading : l10n.topUpSubmitAction,
                          loading: submitting,
                          expand: true,
                          onPressed: submitting ? null : _submit,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Material(
      color: SeenBrand.violet05,
      shape: StadiumBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, textDirection: TextDirection.ltr, style: t.chipM.copyWith(color: c.primary)),
        ),
      ),
    );
  }
}
