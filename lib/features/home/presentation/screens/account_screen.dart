import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/logout_confirm_dialog.dart';
import '../../../profile/presentation/screens/agency_details_screen.dart';
import '../../../profile/presentation/screens/margin_agent_picker_screen.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../profile/presentation/screens/settings_screen.dart';
import '../../../profile/presentation/screens/team_screen.dart';
import '../../../profile/presentation/widgets/session_role.dart';
import '../../../support/presentation/bloc/unread_notifications_cubit.dart';
import '../../../support/presentation/screens/notifications_screen.dart';
import '../../../support/presentation/screens/help_center_screen.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../../profile/presentation/widgets/avatar_flow.dart';
import '../../../profile/presentation/widgets/profile_photo.dart';

/// Figma 14 — account hub (node 18:835): title + bell, profile card, the
/// "Agency" and "App" menus, a sign-out block. Lives as the fifth tab of
/// [AgentShell] (`embedded: true`, bottom bar stays) and can also be pushed
/// standalone from the Home avatar.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.embedded = false, this.versionLoader = _loadVersion, this.pollUnread = true});

  final bool embedded;

  /// Poll the unread notification count (foreground only). Tests turn it off.
  final bool pollUnread;

  /// Resolves the app version string; tests pass a stub.
  final Future<String> Function() versionLoader;

  static Future<String> _loadVersion() async => (await PackageInfo.fromPlatform()).version;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const AccountScreen());

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // Created here (when polling is on), closed in dispose(): it polls only while
  // the app is in the foreground and stops with this screen.
  late final UnreadNotificationsCubit? _unread =
      widget.pollUnread ? (InjectionContainer.instance.createUnreadNotificationsCubit()..start()) : null;

  /// The agency's name from `portalAccount`; until it is read (or when it cannot
  /// be) the card keeps the generic title.
  String? _agencyName;

  @override
  void initState() {
    super.initState();
    if (widget.pollUnread) unawaited(_loadAgencyName());
  }

  Future<void> _loadAgencyName() async {
    try {
      final result = await InjectionContainer.instance.getAgencyProfileUseCase();
      if (!mounted) return;
      result.fold((_) {}, (profile) {
        if (profile.name.isNotEmpty) setState(() => _agencyName = profile.name);
      });
    } on Object {
      // No container in scope (a bare widget test): the generic title stays.
    }
  }

  @override
  void dispose() {
    _unread?.close();
    super.dispose();
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Opens the inbox and reads the count again when it is closed (it was read there).
  Future<void> _openNotifications(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
    unawaited(_unread?.refresh());
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);
    // Figma AUTH-14: say so when signing out would cut an unfinished upload short.
    final confirmed = await showLogoutConfirmDialog(
      context,
      pendingReferences: InjectionContainer.instance.pendingUploads.references,
    );
    if (confirmed != true) return;
    authBloc.add(const AuthLogoutRequested());
    // The auth gate swaps the root screen; drop anything stacked above it.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = SeenType.of(context);
    final permissions = permissionsOf(context);
    final authState = context.read<AuthBloc>().state;
    final role = authState is AuthAuthenticated
        ? switch (authState.session.agentPosition) {
            AgentPosition.owner => l10n.accountRoleOwner,
            AgentPosition.branchManager => l10n.accountRoleBranchManager,
            AgentPosition.staff => l10n.accountRoleStaff,
            _ => null,
          }
        : null;

    final screen = Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              // Header: title at the start, bell at the end.
              Row(
                children: [
                  Expanded(child: Text(l10n.accountTitle, style: t.h1)),
                  _BellButton(
                    label: l10n.notificationsTitle,
                    unread: widget.pollUnread,
                    onTap: () => _openNotifications(context),
                  ),
                ],
              ),
              const SizedBox(height: SeenSpace.s5),
              _ProfileCard(
                title: _agencyName ?? l10n.accountAgencyFallback,
                subtitle: role,
                onPhotoTap: () => changeProfilePhoto(context),
              ),
              const AvatarStatusCard(),
              _SectionLabel(l10n.accountSectionAgency),
              _MenuCard(items: [
                _MenuItem(
                  asset: SeenVectors.accountDocument,
                  title: l10n.accountAgencyDetails,
                  onTap: () => Navigator.of(context).push(AgencyDetailsScreen.route()),
                ),
                if (permissions.can(Capability.margins))
                  _MenuItem(
                    asset: SeenVectors.accountCash,
                    title: l10n.accountItemMargin,
                    onTap: () => Navigator.of(context).push(MarginAgentPickerScreen.route()),
                  ),
                if (permissions.can(Capability.team))
                  _MenuItem(
                    asset: SeenVectors.accountAgents,
                    title: l10n.accountItemUsers,
                    onTap: () => Navigator.of(context).push(TeamScreen.route()),
                  ),
              ]),
              _SectionLabel(l10n.accountSectionApp),
              _MenuCard(items: [
                _MenuItem(
                  asset: SeenVectors.accountBell,
                  title: l10n.notificationsTitle,
                  onTap: () => _openNotifications(context),
                ),
                _MenuItem(
                  asset: SeenVectors.accountSettings,
                  title: l10n.accountItemSettings,
                  onTap: () => Navigator.of(context).push(SettingsScreen.route()),
                ),
                _MenuItem(
                  asset: SeenVectors.accountDocument,
                  title: l10n.helpCenterTitle,
                  onTap: () => _push(context, const HelpCenterScreen()),
                ),
                _MenuItem(
                  asset: SeenVectors.accountSupport,
                  title: l10n.accountSupportTitle,
                  onTap: () => _push(context, const SupportTicketsScreen()),
                ),
              ]),
              const SizedBox(height: 18),
              _SignOutBlock(label: l10n.accountSignOutAction, onTap: () => _confirmSignOut(context)),
              const SizedBox(height: 18),
              _VersionLine(loader: widget.versionLoader),
              SizedBox(height: widget.embedded ? 0 : MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
    final unread = _unread;
    return unread == null ? screen : BlocProvider<UnreadNotificationsCubit>.value(value: unread, child: screen);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.title, this.subtitle, required this.onPhotoTap});

  final String title;
  final String? subtitle;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r22);
    // The title is the agency's name once `portalAccount` answered; the avatar
    // carries a building glyph (the API has no picture to show here).
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SeenBrand.gradientPromo,
        borderRadius: radius,
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: -120,
              width: 261.9,
              height: 377.1,
              child: ExcludeSemantics(child: SvgPicture.asset(SeenVectors.patternGridPromo, fit: BoxFit.fill)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 25),
              child: Row(
                children: [
                  ProfilePhoto(
                    size: 64,
                    onTap: onPhotoTap,
                    fallback: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: SeenBrand.violet40, width: 2),
                      ),
                      child: SizedBox(width: 64, height: 64, child: Icon(SeenIcons.building, size: 28, color: c.primary)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.title),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!, style: t.caption.copyWith(color: c.inkSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 12),
      child: Text(text, style: SeenType.of(context).label.copyWith(color: c.inkMuted)),
    );
  }
}

class _MenuItem {
  const _MenuItem({required this.asset, required this.title, required this.onTap});

  final String asset;
  final String title;
  final VoidCallback onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r22);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              Semantics(
                button: true,
                label: items[i].title,
                excludeSemantics: true,
                child: InkWell(
                  onTap: items[i].onTap,
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: SeenBrand.violet10,
                              borderRadius: BorderRadius.all(SeenRadius.r12),
                            ),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(child: SeenSvgIcon(items[i].asset, size: 20, color: c.primary)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(items[i].title, style: t.bodyStrong)),
                          _Chevron(color: c.inkMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignOutBlock extends StatelessWidget {
  const _SignOutBlock({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final colors = SeenRequestStatus.rejected.colors;
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.bg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
              child: Row(
                children: [
                  SeenSvgIcon(SeenVectors.accountLogout, size: 20, color: colors.fg),
                  const SizedBox(width: 10),
                  Text(label, style: t.bodyStrong.copyWith(color: colors.fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Version x.y.z" under the sign-out block. The future is created once and
/// the line stays hidden while loading or if the platform call fails.
class _VersionLine extends StatefulWidget {
  const _VersionLine({required this.loader});

  final Future<String> Function() loader;

  @override
  State<_VersionLine> createState() => _VersionLineState();
}

class _VersionLineState extends State<_VersionLine> {
  late final Future<String> _version = widget.loader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return FutureBuilder<String>(
      future: _version,
      builder: (context, snapshot) {
        final version = snapshot.data;
        if (version == null || version.isEmpty) return const SizedBox.shrink();
        return Text(
          l10n.accountVersion(SeenFormat.isolate(version)),
          textAlign: TextAlign.center,
          style: SeenType.of(context).caption.copyWith(color: c.inkMuted),
        );
      },
    );
  }
}

/// The exported Figma chevron points left, which is "forward" in RTL; it is
/// mirrored in left-to-right locales.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final ltr = Directionality.of(context) == TextDirection.ltr;
    return Transform.flip(
      flipX: ltr,
      child: SvgPicture.asset(
        SeenVectors.accountChevron,
        width: 6.8,
        height: 11.8,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// Header bell: 44 px circle (Figma "Icon button · bell") with the exported icon.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.label, required this.onTap, this.unread = false});

  final String label;
  final VoidCallback onTap;

  /// Shows the unread count (needs an [UnreadNotificationsCubit] above).
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final bell = Material(
      color: SeenBrand.violet10,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: SeenSvgIcon(SeenVectors.accountBell, size: 22, color: c.primary)),
        ),
      ),
    );
    if (!unread) return Semantics(button: true, label: label, excludeSemantics: true, child: bell);
    return BlocBuilder<UnreadNotificationsCubit, int>(
      builder: (context, count) => Semantics(
        button: true,
        label: count > 0 ? '$label, ${SeenStrings.of(context).unreadCount(count)}' : label,
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bell,
            if (count > 0)
              PositionedDirectional(
                top: -2,
                end: -2,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: SeenBrand.violet, borderRadius: BorderRadius.all(SeenRadius.full)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(
                      count > 99 ? '99+' : SeenStrings.of(context).numeral(count),
                      style: SeenType.of(context).caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
