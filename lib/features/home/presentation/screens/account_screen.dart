import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';

/// Figma 14 — account hub: profile header, agency details, language, theme,
/// support and a confirmed sign-out. Opened from the shell's account tab and
/// the Home avatar.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const AccountScreen());

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountSignOutConfirmTitle),
        content: Text(l10n.accountSignOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.accountSignOutAction)),
        ],
      ),
    );
    if (confirmed != true) return;
    authBloc.add(const AuthLogoutRequested());
    // The auth gate swaps the root screen; drop anything stacked above it.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final authState = context.read<AuthBloc>().state;
    final role = authState is AuthAuthenticated
        ? switch (authState.session.agentPosition) {
            AgentPosition.owner => l10n.accountRoleOwner,
            AgentPosition.branchManager => l10n.accountRoleBranchManager,
            AgentPosition.staff => l10n.accountRoleStaff,
            _ => null,
          }
        : null;

    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              SeenScreenHeader(title: l10n.accountTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 32),
                  children: [
                    // Identity: the session carries no agency or agent name yet,
                    // so the header shows the account kind and the user's role.
                    Column(
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(gradient: SeenBrand.gradientCta, shape: BoxShape.circle),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(SeenIcons.building, size: 32, color: c.onPrimary),
                          ),
                        ),
                        const SizedBox(height: SeenSpace.s3),
                        Text(l10n.accountAgencyFallback, style: t.h1),
                        if (role != null) ...[
                          const SizedBox(height: 2),
                          Text(role, style: t.body.copyWith(color: c.inkMuted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: SeenSpace.s6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: const BorderRadius.all(SeenRadius.r22),
                        border: Border.all(color: c.border),
                        boxShadow: SeenShadows.card,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(SeenRadius.r22),
                        child: Column(
                          children: [
                            _MenuRow(
                              icon: SeenIcons.building,
                              title: l10n.accountAgencyDetails,
                              onTap: () => showSeenSheet<void>(
                                context: context,
                                title: l10n.accountAgencyDetails,
                                builder: (_) => Text(l10n.accountAgencyDetailsSoonBody),
                              ),
                            ),
                            Divider(height: 1, color: c.border),
                            _MenuRow(
                              icon: SeenIcons.globe,
                              title: l10n.accountLanguageTitle,
                              trailingText: l10n.accountLanguageName,
                              onTap: context.read<LocaleCubit>().toggleLocale,
                            ),
                            Divider(height: 1, color: c.border),
                            BlocBuilder<ThemeModeCubit, ThemeMode>(
                              builder: (context, mode) => _MenuRow(
                                icon: switch (mode) {
                                  ThemeMode.light => PhosphorIconsRegular.sun,
                                  ThemeMode.dark => PhosphorIconsRegular.moon,
                                  ThemeMode.system => PhosphorIconsRegular.circleHalf,
                                },
                                title: l10n.accountThemeTitle,
                                onTap: context.read<ThemeModeCubit>().toggleThemeMode,
                              ),
                            ),
                            Divider(height: 1, color: c.border),
                            _MenuRow(
                              icon: SeenIcons.headset,
                              title: l10n.accountSupportTitle,
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute<void>(builder: (_) => const SupportTicketsScreen())),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: SeenSpace.s5),
                    SeenButton.dangerOutline(
                      label: l10n.accountSignOutAction,
                      icon: SeenIcons.x,
                      expand: true,
                      onPressed: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, this.trailingText, this.onTap});

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: trailingText == null ? title : '$title, $trailingText',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r12)),
                child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: c.primary)),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(child: Text(title, style: t.bodyStrong)),
              if (trailingText != null) ...[
                Text(trailingText!, style: t.body.copyWith(color: c.inkMuted)),
                const SizedBox(width: SeenSpace.s2),
              ],
              Icon(SeenIcons.forward(context), size: 18, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
