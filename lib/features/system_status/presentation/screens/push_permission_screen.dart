// Pre-permission screen for notifications (Figma NOTIF-03): why they matter, two
// examples, and what to do when the device permission was refused before.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/system_state.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/services/push_permission_service.dart';
import '../bloc/push_permission_cubit.dart';

class PushPermissionScreen extends StatelessWidget {
  const PushPermissionScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final PushPermissionCubit Function()? createCubit;

  static Route<bool> route() => MaterialPageRoute<bool>(builder: (_) => const PushPermissionScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createPushPermissionCubit)()..load(),
      child: BlocConsumer<PushPermissionCubit, PushPermissionState>(
        listenWhen: (p, c) => p.outcome != c.outcome && c.outcome != PushOutcome.none,
        listener: (context, state) {
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          switch (state.outcome) {
            case PushOutcome.granted:
              // Say it on the screen underneath, then leave.
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.pushEnabled)));
              navigator.pop(true);
            case PushOutcome.settingsUnavailable:
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.pushSettingsHint)));
            case PushOutcome.refused || PushOutcome.openedSettings || PushOutcome.none:
              break;
          }
        },
        builder: (context, state) {
          final cubit = context.read<PushPermissionCubit>();
          final denied = state.status == PushPermissionStatus.denied || state.outcome == PushOutcome.refused;
          return Scaffold(
            backgroundColor: SeenColors.of(context).card,
            body: SeenScreenBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: SeenSystemMessage(
                            illustration: SeenSystemIllustration(icon: SeenIcons.bell),
                            title: s.pushTitle,
                            body: s.pushBody,
                            below: [
                              const SizedBox(height: 14),
                              const _Examples(),
                              if (denied) ...[
                                const SizedBox(height: 14),
                                _DeniedBanner(onSettings: cubit.openSettings),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    SeenActionBar(
                      actions: [
                        SeenButton(
                          label: s.enableNotifications,
                          expand: true,
                          loading: state.busy,
                          onPressed: state.status == null ? null : cubit.enable,
                        ),
                        SeenButton.ghost(
                          label: s.maybeLater,
                          expand: true,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    Widget row(String text, SeenRequestStatus tone) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: tone.colors.bg, borderRadius: const BorderRadius.all(SeenRadius.full)),
                child: SizedBox(
                  height: 26,
                  width: 34,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: tone.colors.fg, shape: BoxShape.circle),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: t.label)),
            ],
          ),
        );
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
          children: [
            row(s.pushExampleIssued, SeenRequestStatus.completed),
            row(s.pushExampleDocument(46), SeenRequestStatus.actionRequired),
          ],
        ),
      ),
    );
  }
}

class _DeniedBanner extends StatelessWidget {
  const _DeniedBanner({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return SeenInlineBanner(
      tone: SeenBannerTone.info,
      message: s.pushDeniedBanner,
      actionLabel: s.deviceSettings,
      onAction: onSettings,
    );
  }
}
