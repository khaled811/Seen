import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/topup_widgets.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';

/// Figma 12 (node 18:619) — full-page top-up request: payment method cards,
/// the bank details card, the amount with preset chips, the receipt slot and a
/// sticky submit bar. The wallet screen owns the [WalletBloc]; this route
/// re-provides it with `BlocProvider.value`.
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
  // Figma lists the chips 100 · 250 · 500 · 1,000 (first at the start edge).
  static const _presets = [100, 250, 500, 1000];
  static const _presetLabels = ['100', '250', '500', '1,000'];

  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  TopUpMethod _method = TopUpMethod.bankTransfer;

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
    const gap = SizedBox(height: 18);

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
                        SeenTextField(
                          label: l10n.topUpReferenceNumberLabel,
                          isRequired: true,
                          controller: _referenceController,
                          mono: true,
                          ltr: true,
                          validator: (v) => FormValidators.required(v, message: l10n.validationRequired),
                        ),
                        gap,
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
