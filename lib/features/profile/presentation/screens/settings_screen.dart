// Settings (Figma ACC-04): language, appearance, notifications, branches, security,
// "hide the balance by default" and about. Rows whose destination is not built yet say
// so instead of leading nowhere.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/preferences/balance_privacy_cubit.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/gallery/components_gallery_screen.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../home/presentation/widgets/role_strings.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../auth/presentation/screens/change_phone_screen.dart';
import '../../../auth/presentation/bloc/email_change_cubit.dart';
import '../../../auth/presentation/bloc/two_factor_cubits.dart';
import '../../../auth/presentation/screens/change_email_screen.dart';
import '../../../auth/presentation/screens/two_factor_setup_screen.dart';
import '../../../support/presentation/screens/notification_preferences_screen.dart';
import '../widgets/language_confirm_dialog.dart';
import '../widgets/session_role.dart';
import 'about_screen.dart';
import 'branches_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.versionLoader = _loadVersion, this.permissions, this.createTwoFactorStatusCubit, this.createEmailChangeCubit});

  /// Resolves the app version; tests pass a stub.
  final Future<String> Function() versionLoader;

  /// Test seam; defaults to the signed-in role.
  final RolePermissions? permissions;

  /// Test seam; defaults to the DI container.
  final TwoFactorStatusCubit Function()? createTwoFactorStatusCubit;
  final EmailChangeCubit Function()? createEmailChangeCubit;

  static Future<String> _loadVersion() async => (await PackageInfo.fromPlatform()).version;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  /// Asks first (Figma ACC-05): the direction of the whole interface flips.
  Future<void> _switchLanguage(BuildContext context, String current) async {
    final cubit = context.read<LocaleCubit>();
    final confirmed = await showLanguageConfirmDialog(context, toEnglish: current != 'en');
    if (confirmed) {
      await cubit.toggleLocale();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final perms = permissions ?? permissionsOf(context);
    final lang = Localizations.localeOf(context).languageCode;
    final themeMode = context.watch<ThemeModeCubit>().state;
    final light = switch (themeMode) {
      ThemeMode.light => true,
      ThemeMode.dark => false,
      ThemeMode.system => null,
    };
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: s.settingsTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
                  children: [
                    _Card(rows: [
                      _Row(
                        icon: SeenIcons.globe,
                        title: s.languageRow,
                        value: s.languageName(lang),
                        onTap: () => _switchLanguage(context, lang),
                      ),
                      _Row(
                        icon: SeenIcons.eye,
                        title: s.themeRow,
                        value: s.themeValue(light),
                        onTap: context.read<ThemeModeCubit>().toggleThemeMode,
                      ),
                      _Row(
                        icon: SeenIcons.bell,
                        title: s.notificationsRow,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(NotificationPreferencesScreen.route()),
                      ),
                      if (perms.can(Capability.branches))
                        _Row(
                          icon: SeenIcons.building,
                          title: s.branchesRow,
                          chevron: true,
                          onTap: () => Navigator.of(context).push(BranchesScreen.route()),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _Card(rows: [
                      _Row(
                        icon: SeenIcons.lock,
                        title: s.changePasswordRow,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(ChangePasswordScreen.route()),
                      ),
                      BlocProvider(
                        create: (_) => (createEmailChangeCubit ?? InjectionContainer.instance.createEmailChangeCubit)()..load(),
                        child: const _ChangeEmailRow(),
                      ),
                      _Row(
                        icon: SeenIcons.passport,
                        title: s.changePhoneRow,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(ChangePhoneScreen.route()),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    BlocProvider(
                      create: (_) => (createTwoFactorStatusCubit ?? InjectionContainer.instance.createTwoFactorStatusCubit)()..load(),
                      child: const _TwoFactorCard(),
                    ),
                    const SizedBox(height: 12),
                    _Card(rows: [
                      // Needs a device-authentication plugin the app does not ship: shown
                      // off and unavailable rather than a switch that does nothing.
                      _Toggle(title: s.biometricRow, subtitle: s.biometricUnavailable, value: false, onChanged: null),
                      BlocBuilder<BalancePrivacyCubit, bool>(
                        builder: (context, hidden) => _Toggle(
                          title: s.hideBalanceRow,
                          value: hidden,
                          onChanged: context.read<BalancePrivacyCubit>().setHidden,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (kDebugMode) ...[
                      _Card(rows: [
                        _Row(
                          icon: SeenIcons.list,
                          title: 'Components (debug)',
                          chevron: true,
                          onTap: () => Navigator.of(context).push(ComponentsGalleryScreen.route()),
                        ),
                      ]),
                      const SizedBox(height: 12),
                    ],
                    FutureBuilder<String>(
                      future: versionLoader(),
                      builder: (context, snap) => _Row(
                        icon: SeenIcons.file,
                        title: s.aboutRow,
                        subtitle: snap.hasData ? s.versionLine(snap.data!) : null,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(AboutScreen.route()),
                        last: true,
                        flat: true,
                      ),
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

/// «Change e-mail» (Figma ACC-08): under «change password», with the current address as its line.
class _ChangeEmailRow extends StatelessWidget {
  const _ChangeEmailRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final email = context.select((EmailChangeCubit cubit) => cubit.state.currentEmail);
    return _Row(
      icon: SeenIcons.mail,
      title: l10n.accChangeEmail,
      subtitle: email == null || email.isEmpty ? null : SeenFormat.isolate(email),
      chevron: true,
      onTap: () => Navigator.of(context).push(ChangeEmailScreen.route()),
    );
  }
}

/// Two-step verification (Figma SEC-01): the status, how to turn it on, and the recovery codes.
/// The contract has no operation to turn it off, so there is no such row (DECISIONS D-34).
class _TwoFactorCard extends StatelessWidget {
  const _TwoFactorCard();

  Future<void> _open(BuildContext context, TwoFactorFlowMode mode) async {
    final cubit = context.read<TwoFactorStatusCubit>();
    await Navigator.of(context).push(TwoFactorSetupScreen.route(mode));
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocBuilder<TwoFactorStatusCubit, TwoFactorStatusState>(
      builder: (context, state) {
        if (state.loading) {
          return const _Card(rows: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                SeenSkeletonBox(width: 36, height: 36, radius: 11),
                SizedBox(width: 12),
                Expanded(child: SeenSkeletonBox(height: 14)),
              ]),
            ),
          ]);
        }
        final status = state.status;
        if (status == null) {
          return _Card(rows: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.secLoadError),
                const SizedBox(height: 10),
                SeenButton.outline(
                  label: l10n.commonRetry,
                  size: SeenButtonSize.small,
                  onPressed: context.read<TwoFactorStatusCubit>().load,
                ),
              ]),
            ),
          ]);
        }
        if (!status.isOn) {
          return _Card(rows: [
            _Row(icon: SeenIcons.shield, title: l10n.secTfaTitle, subtitle: l10n.secTfaSub, value: l10n.secTfaOff),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.secTfaPitch, style: t.caption.copyWith(color: c.inkSecondary)),
                  const SizedBox(height: 10),
                  SeenButton(
                    label: l10n.secTfaEnable,
                    size: SeenButtonSize.small,
                    onPressed: () => _open(context, TwoFactorFlowMode.enable),
                  ),
                ],
              ),
            ),
          ]);
        }
        return _Card(rows: [
          _Row(icon: SeenIcons.shield, title: l10n.secTfaTitle, subtitle: l10n.secTfaSub, value: l10n.secTfaOn),
          _Row(icon: SeenIcons.lock, title: l10n.secRecoveryCodes, subtitle: SeenStrings.of(context).digits(l10n.secRecoveryCodesLeft(status.recoveryCodesLeft))),
          _Row(
            icon: SeenIcons.refresh,
            title: l10n.secRegenerate,
            subtitle: l10n.secRegenerateSub,
            chevron: true,
            onTap: () => _open(context, TwoFactorFlowMode.regenerate),
          ),
        ]);
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: rows)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.chevron = false,
    this.onTap,
    this.last = false,
    this.flat = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final bool chevron;
  final VoidCallback? onTap;
  final bool last;

  /// Without the card's rule and border (the lone "about" row).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(border: flat ? null : Border(bottom: BorderSide(color: c.border))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
                child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: SeenBrand.violet)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body),
                    if (subtitle != null) Text(subtitle!, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              if (value != null) Text(value!, style: t.label.copyWith(color: c.inkSecondary)),
              if (chevron) Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;

  /// null = disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.body.copyWith(color: onChanged == null ? c.inkMuted : c.ink)),
                  if (subtitle != null) Text(subtitle!, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            SeenSwitch(value: value, onChanged: onChanged, semanticLabel: title),
          ],
        ),
      ),
    );
  }
}
