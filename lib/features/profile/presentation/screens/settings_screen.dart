// Settings (Figma ACC-04): language, appearance, notifications, branches, security,
// "hide the balance by default" and about. Rows whose destination is not built yet say
// so instead of leading nowhere.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/preferences/balance_privacy_cubit.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/gallery/components_gallery_screen.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../home/presentation/widgets/role_strings.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../auth/presentation/screens/change_phone_screen.dart';
import '../../../support/presentation/screens/notification_preferences_screen.dart';
import '../widgets/language_confirm_dialog.dart';
import '../widgets/session_role.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.versionLoader = _loadVersion, this.permissions});

  /// Resolves the app version; tests pass a stub.
  final Future<String> Function() versionLoader;

  /// Test seam; defaults to the signed-in role.
  final RolePermissions? permissions;

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

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)));
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
                      if (perms.can(Capability.team))
                        _Row(icon: SeenIcons.building, title: s.branchesRow, chevron: true, onTap: () => _soon(context)),
                    ]),
                    const SizedBox(height: 12),
                    _Card(rows: [
                      _Row(
                        icon: SeenIcons.lock,
                        title: s.changePasswordRow,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(ChangePasswordScreen.route()),
                      ),
                      _Row(
                        icon: SeenIcons.passport,
                        title: s.changePhoneRow,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(ChangePhoneScreen.route()),
                      ),
                    ]),
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
