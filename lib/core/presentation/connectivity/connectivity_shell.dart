import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../theme/seen_format.dart';
import '../widgets/inline_banner.dart';
import 'connectivity_cubit.dart';

/// Puts the connectivity banner (Figma SYS-01) above the whole app. While the
/// banner shows it takes the top safe-area inset, so the screen below drops its
/// own to avoid a double gap. Wrap the Navigator with it from `MaterialApp.builder`.
class SeenConnectivityShell extends StatelessWidget {
  const SeenConnectivityShell({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final visible = state.status != ConnectivityStatus.online && l10n != null;
        final content = child ?? const SizedBox.shrink();
        if (!visible) return content;
        final cubit = context.read<ConnectivityCubit>();
        final banner = state.status == ConnectivityStatus.offline
            ? SeenInlineBanner(
                tone: SeenBannerTone.offline,
                message: state.lastSyncedAt == null
                    ? l10n.connectivityOfflineNoTime
                    : l10n.connectivityOffline(SeenFormat.time(state.lastSyncedAt!)),
                actionLabel: l10n.connectivityRetry,
                onAction: cubit.recheck,
              )
            : SeenInlineBanner(
                tone: SeenBannerTone.ok,
                message: l10n.connectivityRestored,
              );
        return Column(
          children: [
            Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: banner),
              ),
            ),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: content)),
          ],
        );
      },
    );
  }
}
