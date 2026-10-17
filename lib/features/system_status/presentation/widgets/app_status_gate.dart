// Puts the maintenance / required-update screens over the whole app and floats the
// optional-update card above it. The app underneath stays mounted (navigation and
// typed values survive a maintenance window) but is unreachable while blocked.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../domain/services/store_launcher.dart';
import '../bloc/app_status_cubit.dart';
import '../screens/force_update_screen.dart';
import '../screens/maintenance_screen.dart';
import 'soft_update_card.dart';

class AppStatusGate extends StatefulWidget {
  const AppStatusGate(
      {super.key, required this.child, required this.storeLauncher});

  final Widget child;
  final StoreLauncher storeLauncher;

  @override
  State<AppStatusGate> createState() => _AppStatusGateState();
}

class _AppStatusGateState extends State<AppStatusGate>
    with WidgetsBindingObserver {
  // Registered in initState, removed in dispose.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppStatusCubit>().checkOnResume();
    }
  }

  Future<void> _openStore(String? url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = SeenStrings.of(context).storeUnavailable;
    final ok = url != null && await widget.storeLauncher.open(url);
    if (!ok) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppStatusCubit, AppStatusState>(
      builder: (context, state) {
        final blocked =
            state is AppStatusMaintenance || state is AppStatusUpdateRequired;
        return Stack(
          children: [
            // Unreachable (touch and screen reader) while a blocking screen is up.
            Positioned.fill(
              child: ExcludeSemantics(
                  excluding: blocked,
                  child: IgnorePointer(ignoring: blocked, child: widget.child)),
            ),
            switch (state) {
              AppStatusMaintenance(:final eta, :final checking) =>
                Positioned.fill(
                  child: MaintenanceScreen(
                    eta: eta,
                    checking: checking,
                    onRetry: () => context.read<AppStatusCubit>().check(),
                  ),
                ),
              AppStatusUpdateRequired(:final storeUrl) => Positioned.fill(
                  child: ForceUpdateScreen(
                      onUpdate:
                          storeUrl == null ? null : () => _openStore(storeUrl)),
                ),
              AppStatusUpdateAvailable(
                :final version,
                :final note,
                :final storeUrl
              ) =>
                PositionedDirectional(
                  start: 20,
                  end: 20,
                  bottom: 100,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SoftUpdateCard(
                      version: version,
                      note: note,
                      onUpdate:
                          storeUrl == null ? null : () => _openStore(storeUrl),
                      onLater: () =>
                          context.read<AppStatusCubit>().postponeUpdate(),
                    ),
                  ),
                ),
              AppStatusOpen() => const SizedBox.shrink(),
            },
          ],
        );
      },
    );
  }
}
