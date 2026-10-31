import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
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
import '../../../../core/presentation/widgets/loading/seen_blocking_overlay.dart';
import '../../../../core/presentation/widgets/loading/loading_strings.dart';
import '../../../requests/presentation/bloc/staged_attachment_cubit.dart';
import '../../domain/entities/top_up_options.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/seen_receipt_slot.dart';
import '../widgets/topup_widgets.dart';
import 'top_up_submitted_screen.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';

/// The data a resubmission starts from (a rejected top-up, Figma WAL-03). The
/// receipt is not part of it: a new one is attached to the new request.
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
/// The server refuses a transfer reference longer than this (`submitTopUp`).
const topUpReferenceMaxLength = 64;

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

  // Created here, closed in dispose(): the receipt is sent as soon as it is picked.
  late final StagedAttachmentCubit _receipt = InjectionContainer.instance.createStagedAttachmentCubit();

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
    _receipt.close();
    super.dispose();
  }

  int get _selectedPreset {
    final value = num.tryParse(_amountController.text.trim());
    return value == null ? -1 : _presets.indexOf(value.toInt() == value ? value.toInt() : -1);
  }

  /// The top-up options the wallet loaded (accounts, methods, minimum); null
  /// while unknown.
  TopUpOptions? _options() {
    final state = context.read<WalletBloc>().state;
    return state is WalletLoaded ? state.topUpOptions : null;
  }

  /// The methods to offer: the server's list when there is one, otherwise all.
  static List<TopUpMethod> _methodsFor(TopUpOptions? options) {
    final fromServer = [for (final m in options?.methods ?? const <TopUpMethodOption>[]) m.method];
    return fromServer.isEmpty
        ? const [TopUpMethod.bankTransfer, TopUpMethod.cash, TopUpMethod.exchangeHouse]
        : fromServer;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final options = _options();
    if (options != null && !options.canRequest) return;
    // A receipt still being sent is waited for, not dropped.
    if (_receipt.state.uploading) return;
    final methods = _methodsFor(options);
    final method = methods.contains(_method) ? _method : methods.first;
    context.read<WalletBloc>().add(
          WalletTopUpSubmitted(
            amountCents: MoneyParser.centsFromDecimalString(_amountController.text.trim()),
            method: method,
            referenceNumber: _referenceController.text.trim(),
            paymentAccountId: options?.accountsFor(method).firstOrNull?.id,
            receiptFileId: _receipt.state.fileId,
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
    // Where to pay comes from the server (`portalTopUpOptions`); the app never
    // invents account details. Constructor values win (callers and tests).
    final options = context.select<WalletBloc, TopUpOptions?>((b) {
      final s = b.state;
      return s is WalletLoaded ? s.topUpOptions : null;
    });
    final methods = _methodsFor(options);
    final method = methods.contains(_method) ? _method : methods.first;
    final bankAccount = options?.accountsFor(TopUpMethod.bankTransfer).firstOrNull;
    final bank = widget.bankDetails ??
        (bankAccount == null
            ? null
            : TopUpBankDetails(
                bankName: bankAccount.bankName.isEmpty ? bankAccount.title : bankAccount.bankName,
                accountName: bankAccount.holder,
                iban: bankAccount.accountNumber,
                currency: bankAccount.currency.isEmpty ? 'USD' : bankAccount.currency,
              ));
    final otherAccount = options?.accountsFor(method).firstOrNull;
    final alternative = widget.alternativeDetails ??
        (otherAccount == null || method == TopUpMethod.bankTransfer
            ? null
            : TopUpAlternativeDetails(
                recipientName: otherAccount.holder.isEmpty ? otherAccount.title : otherAccount.holder,
                branchAddress: otherAccount.instructions.isEmpty ? null : otherAccount.instructions,
              ));
    final currency = (options?.currency.isNotEmpty ?? false) ? options!.currency : 'USD';
    final exchange = method == TopUpMethod.exchangeHouse;
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
            _toast(failureTextOr(l10n, loaded.topUpFailure, loaded.topUpError ?? l10n.error));
            context.read<WalletBloc>().add(const WalletTopUpStatusCleared());
          case TopUpSubmissionStatus.idle:
          case TopUpSubmissionStatus.submitting:
            break;
        }
      },
      child: BlocSelector<WalletBloc, WalletState, bool>(
        selector: (state) => state is WalletLoaded && state.topUpStatus == TopUpSubmissionStatus.submitting,
        builder: (context, submitting) => SeenBlockingOverlay(
          visible: submitting,
          title: SeenStrings.of(context).submittingTopUp,
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
                          value: method,
                          onChanged: (v) => setState(() => _method = v),
                          options: [
                            for (final m in methods)
                              SeenMethodCardOption(
                                value: m,
                                iconAsset: switch (m) {
                                  TopUpMethod.bankTransfer => SeenVectors.walletBank,
                                  TopUpMethod.cash => SeenVectors.walletCash,
                                  _ => SeenVectors.walletIcon,
                                },
                                label: WalletLabels.topUpMethod(l10n, m),
                              ),
                          ],
                        ),
                        if (method == TopUpMethod.bankTransfer) ...[
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
                            inputFormatters: [LengthLimitingTextInputFormatter(topUpReferenceMaxLength)],
                            onChanged: (_) => setState(() {}),
                            prefix: _referenceController.text.trim().isEmpty
                                ? null
                                : SeenCheckGlyph(size: 20, color: SeenRequestStatus.completed.colors.fg),
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
                            if (alternative.agentCode != null) ...[
                              gap,
                              SeenTextField(
                                key: const ValueKey('topUpAgentCode'),
                                label: l10n.topUpAgentCodeLabel,
                                readOnly: true,
                                mono: true,
                                ltr: true,
                                initialValue: alternative.agentCode,
                              ),
                            ],
                          ] else ...[
                            gap,
                            Text(l10n.topUpAlternativeUnavailable, style: t.body.copyWith(color: c.inkSecondary)),
                          ],
                        ],
                        if (method == TopUpMethod.cash) ...[
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
                          suffixText: currency,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final invalid = FormValidators.positiveAmount(v, message: l10n.validationInvalidAmount);
                            if (invalid != null) return invalid;
                            final min = options?.minimumAmountCents;
                            if (min != null && MoneyParser.centsFromDecimalString(v!.trim()) < min) {
                              return l10n.topUpBelowMinimum('${MoneyParser.decimalStringFromCents(min)} $currency');
                            }
                            return null;
                          },
                        ),
                        gap,
                        SeenAmountChips(
                          labels: _presetLabels,
                          selectedIndex: _selectedPreset,
                          onSelected: (i) => setState(() => _amountController.text = '${_presets[i]}.00'),
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
                            inputFormatters: [LengthLimitingTextInputFormatter(topUpReferenceMaxLength)],
                            validator: (v) => FormValidators.required(v, message: l10n.validationRequired),
                          ),
                          gap,
                        ],
                        Text(l10n.topUpReceiptSection, style: t.h2),
                        gap,
                        BlocProvider<StagedAttachmentCubit>.value(
                          value: _receipt,
                          child: SeenReceiptSlot(
                            title: l10n.topUpReceiptLabel,
                            caption: SeenStrings.of(context).attachTypes,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<WalletBloc, WalletState>(
                  buildWhen: (p, c) => c is WalletLoaded && (p is! WalletLoaded || p.topUpStatus != c.topUpStatus),
                  builder: (context, state) {
                    final submitting = state is WalletLoaded && state.topUpStatus == TopUpSubmissionStatus.submitting;
                    // The server says whether this person may request a top-up.
                    final allowed = state is! WalletLoaded || (state.topUpOptions?.canRequest ?? true);
                    return SeenActionBar(
                      actions: [
                        if (!allowed) Text(l10n.errorForbidden, style: t.body.copyWith(color: c.inkSecondary)),
                        SeenButton(
                          label: submitting ? l10n.loading : l10n.topUpSubmitAction,
                          loading: submitting,
                          expand: true,
                          onPressed: submitting || !allowed ? null : _submit,
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
      if (details.agentCode != null) l10n.topUpCashStepCode(SeenFormat.isolate(details.agentCode!)),
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
