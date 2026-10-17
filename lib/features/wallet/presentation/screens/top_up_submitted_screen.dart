// Top-up submitted (Figma WAL-05): confirms the request was sent, with its
// reference, and offers the request itself or the way back to the wallet.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import 'wallet_transaction_detail_screen.dart';

class TopUpSubmittedScreen extends StatelessWidget {
  const TopUpSubmittedScreen({super.key, required this.transaction});

  /// The pending request that was just created.
  final WalletTransaction transaction;

  Future<void> _viewRequest(BuildContext context) async {
    final wallet = context.read<WalletBloc>();
    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: wallet,
          child: WalletTransactionDetailScreen(transaction: transaction),
        ),
      ),
    );
    // Cancelled from the detail: nothing left to confirm, go back to the wallet.
    if (changed == true) {
      wallet.add(const WalletLoadRequested());
      if (navigator.mounted) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final code = transaction.topUp?.code;
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.border),
                            gradient: const LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [Color(0xFFE5DCFD), Color(0xFFFFFFFF)],
                            ),
                          ),
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: const BorderRadius.all(SeenRadius.r20),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x1F2C186A), blurRadius: 16, offset: Offset(0, 12)),
                                  ],
                                ),
                                child: const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(child: SeenSvgIcon(SeenVectors.walletClock, size: 36)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Semantics(
                          header: true,
                          child: Text(l10n.walletTopUpSentTitle, textAlign: TextAlign.center, style: t.h1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          code == null
                              ? l10n.walletTopUpSentBodyNoCode
                              : l10n.walletTopUpSentBody(SeenFormat.isolate(code)),
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(color: c.inkSecondary),
                        ),
                        const SizedBox(height: 12),
                        SeenStatusChip(status: SeenRequestStatus.underReview, label: l10n.requestDocStatusInReview),
                      ],
                    ),
                  ),
                ),
              ),
              SeenActionBar(
                actions: [
                  SeenButton(
                    label: l10n.walletTxnViewRequest,
                    expand: true,
                    onPressed: () => _viewRequest(context),
                  ),
                  SeenButton.outline(
                    label: l10n.walletBackToWallet,
                    expand: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
