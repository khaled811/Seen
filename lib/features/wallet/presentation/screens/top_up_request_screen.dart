import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
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
import '../widgets/topup_widgets.dart';
import 'top_up_submitted_screen.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';

/// The data a resubmission starts from (a rejected top-up, Figma WAL-03). The
/// receipt is not part of it: the form has no receipt upload yet.
class TopUpPrefill {
  const TopUpPrefill({required this.amountCents, required this.method, this.referenceNumber});

  final int amountCents;
  final TopUpMethod method;
  final String? referenceNumber;
}

/// Figma 12 (node 18:619) — full-page top-up request: payment method cards,
/// the bank details card, the amount with preset chips, the receipt slot and a
/// sticky submit bar. The wallet screen owns the [WalletBloc]; this route
/// re-provides it with `BlocProvider.value`.
class TopUpRequestScreen extends StatefulWidget {
  const TopUpRequestScreen({super.key, this.bankDetails, this.alternativeDetails, this.prefill});

  /// Starts the form from a rejected request's data (Figma WAL-03).
  final TopUpPrefill? prefill;

  /// The company account the agent wires money to. The backend does not expose
  /// it yet, so release builds show a "support will send it" note instead of
  /// inventing details; debug builds show an obvious placeholder.
  final TopUpBankDetails? bankDetails;

  /// Who receives cash / an exchange-house transfer, and the agent's code.
  /// Like [bankDetails]: not exposed by the backend yet, so release builds show a
  /// "support will send it" note and debug builds an obvious placeholder.
  final TopUpAlternativeDetails? alternativeDetails;

  static const _debugAlternative = TopUpAlternativeDetails(
    recipientName: 'Sample Beneficiary (debug)',
    agentCode: 'AG-0000',
    branchAddress: 'Sample branch (debug)',
  );

  static const _debugSample = TopUpBankDetails(
    bankName: 'Sample Bank (debug)',
    accountName: 'Sample Beneficiary',
    iban: 'XX00 0000 0000 0000 0000',
  );

  static Route<void> route(
    WalletBloc bloc, {
    TopUpBankDetails? bankDetails,
    TopUpAlternativeDetails? alternativeDetails,
    TopUpPrefill? prefill,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: TopUpRequestScreen(bankDetails: bankDetails, alternativeDetails: alternativeDetails, prefill: prefill),
        ),
      );

  @override
  State<TopUpRequestScreen> createState() => _TopUpRequestScreenState();
}

class _TopUpRequestScreenState extends State<TopUpRequestScreen> {
  // Figma lists the chips 100 · 250 · 500 · 1,000 (first at the start edge).
  static const _presets = [100, 250, 500, 1000];
  static const _presetLabels = ['100', '250', '500', '1,000'];

  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  TopUpMethod _method = TopUpMethod.bankTransfer;

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      _amountController.text = MoneyParser.decimalStringFromCents(prefill.amountCents);
      _referenceController.text = prefill.referenceNumber ?? '';
      if (prefill.method != TopUpMethod.unknown) _method = prefill.method;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  int get _selectedPreset {
    final value = num.tryParse(_amountController.text.trim());
    return value == null ? -1 : _presets.indexOf(value.toInt() == value ? value.toInt() : -1);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<WalletBloc>().add(
          WalletTopUpSubmitted(
            amountCents: MoneyParser.centsFromDecimalString(_amountController.text.trim()),
            method: _method,
            referenceNumber: _referenceController.text.trim(),
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
    final alternative = widget.alternativeDetails ?? (kDebugMode ? TopUpRequestScreen._debugAlternative : null);
    final exchange = _method == TopUpMethod.exchangeHouse;
    const gap = SizedBox(height: 18);

    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) => current is WalletLoaded && current.topUpStatus != TopUpSubmissionStatus.idle,
      listener: (context, state) {
        final loaded = state as WalletLoaded;
        switch (loaded.topUpStatus) {
          case TopUpSubmissionStatus.success:
            final bloc = context.read<WalletBloc>();
            final created = loaded.submittedTopUp;
            bloc.add(const WalletTopUpStatusCleared());
            if (created == null) {
              _toast(l10n.topUpSuccessMessage);
              Navigator.of(context).pop();
            } else {
              // Figma WAL-05: confirm, with the reference, instead of a toast.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(value: bloc, child: TopUpSubmittedScreen(transaction: created)),
                ),
              );
            }
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(l10n.topUpPaymentMethodLabel, style: t.h2),
                        gap,
                        SeenMethodCards<TopUpMethod>(
                          value: _method,
                          onChanged: (v) => setState(() => _method = v),
                          options: [
                            SeenMethodCardOption(
                              value: TopUpMethod.bankTransfer,
                              iconAsset: SeenVectors.walletBank,
                              label: WalletLabels.topUpMethod(l10n, TopUpMethod.bankTransfer),
                            ),
                            SeenMethodCardOption(
                              value: TopUpMethod.cash,
                              iconAsset: SeenVectors.walletCash,
                              label: WalletLabels.topUpMethod(l10n, TopUpMethod.cash),
                            ),
                            SeenMethodCardOption(
                              value: TopUpMethod.exchangeHouse,
                              iconAsset: SeenVectors.walletIcon,
                              label: WalletLabels.topUpMethod(l10n, TopUpMethod.exchangeHouse),
                            ),
                          ],
                        ),
                        if (_method == TopUpMethod.bankTransfer) ...[
                          gap,
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
                        if (exchange) ...[
                          gap,
                          // Figma WAL-11: what to quote at the exchange house.
                          Text(l10n.topUpExchangeSection, style: t.h2),
                          gap,
                          SeenTextField(
                            label: l10n.topUpTransferNumberLabel,
                            isRequired: true,
                            controller: _referenceController,
                            mono: true,
                            ltr: true,
                            onChanged: (_) => setState(() {}),
                            prefix: _referenceController.text.trim().isEmpty
                                ? null
                                : Icon(SeenIcons.check, size: 20, color: SeenRequestStatus.completed.colors.fg),
                            validator: (v) => FormValidators.required(v, message: l10n.validationRequired),
                          ),
                          if (alternative != null) ...[
                            gap,
                            SeenTextField(
                              // A key: the value comes from `initialValue`, which a reused field state would ignore.
                              key: const ValueKey('topUpRecipient'),
                              label: l10n.topUpRecipientLabel,
                              readOnly: true,
                              initialValue: alternative.recipientName,
                            ),
                            gap,
                            SeenTextField(
                              key: const ValueKey('topUpAgentCode'),
                              label: l10n.topUpAgentCodeLabel,
                              readOnly: true,
                              mono: true,
                              ltr: true,
                              initialValue: alternative.agentCode,
                            ),
                          ] else ...[
                            gap,
                            Text(l10n.topUpAlternativeUnavailable, style: t.body.copyWith(color: c.inkSecondary)),
                          ],
                        ],
                        if (_method == TopUpMethod.cash) ...[
                          gap,
                          if (alternative != null)
                            _CashInstructions(details: alternative)
                          else
                            Text(l10n.topUpAlternativeUnavailable, style: t.body.copyWith(color: c.inkSecondary)),
                        ],
                        gap,
                        Text(l10n.topUpAmountSection, style: t.h2),
                        gap,
                        SeenTextField(
                          label: l10n.topUpAmountLabel,
                          isRequired: true,
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          mono: true,
                          ltr: true,
                          suffixText: 'USD',
                          onChanged: (_) => setState(() {}),
                          validator: (v) => FormValidators.positiveAmount(v, message: l10n.validationInvalidAmount),
                        ),
                        gap,
                        SeenAmountChips(
                          labels: _presetLabels,
                          selectedIndex: _selectedPreset,
                          onSelected: (i) => setState(() => _amountController.text = _presets[i].toStringAsFixed(2)),
                        ),
                        gap,
                        // The API requires the bank's transfer reference; Figma has no field for it.
                        // (For an exchange house it is the transfer-number field above.)
                        if (!exchange) ...[
                          SeenTextField(
                            label: l10n.topUpReferenceNumberLabel,
                            isRequired: true,
                            controller: _referenceController,
                            mono: true,
                            ltr: true,
                            validator: (v) => FormValidators.required(v, message: l10n.validationRequired),
                          ),
                          gap,
                        ],
                        Text(l10n.topUpReceiptSection, style: t.h2),
                        gap,
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
                  buildWhen: (p, c) => c is WalletLoaded && (p is! WalletLoaded || p.topUpStatus != c.topUpStatus),
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

/// Figma WAL-11 "Cash instructions": where to go, what to say, what to bring back.
class _CashInstructions extends StatelessWidget {
  const _CashInstructions({required this.details});

  final TopUpAlternativeDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final steps = [
      if (details.branchAddress != null) l10n.topUpCashStepBranch(details.branchAddress!),
      l10n.topUpCashStepCode(SeenFormat.isolate(details.agentCode)),
      l10n.topUpCashStepReceipt,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SeenSvgIcon(SeenVectors.walletCash, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.topUpCashTitle, style: t.label.copyWith(color: c.ink))),
              ],
            ),
            for (final step in steps) ...[
              const SizedBox(height: 8),
              Text(step, style: t.caption.copyWith(color: c.inkSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
