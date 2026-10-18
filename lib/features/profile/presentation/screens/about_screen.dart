// About the app (Figma ACC-06): logo, version and build, the legal texts, open-source
// licences, "rate the app" and the copyright line.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../home/presentation/widgets/role_strings.dart' show RoleStrings;
import '../../../legal/domain/entities/legal_document.dart';
import '../../../legal/presentation/screens/legal_document_screen.dart';
import '../../../system_status/domain/services/store_launcher.dart';
import '../../../system_status/presentation/bloc/app_status_cubit.dart';

/// "2.4.0" and "318".
typedef AppVersionInfo = ({String version, String build});

Future<AppVersionInfo> _loadVersion() async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, build: info.buildNumber);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.versionLoader = _loadVersion, this.launcher, this.storeUrl, this.now});

  /// Test seams: the version, the store opener, the store link and the clock.
  final Future<AppVersionInfo> Function() versionLoader;
  final StoreLauncher? launcher;
  final String? storeUrl;
  final DateTime? now;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const AboutScreen());

  /// The store link the server last reported (it comes with the app-status check), if any.
  String? _storeUrl(BuildContext context) {
    if (storeUrl != null) {
      return storeUrl;
    }
    try {
      return context.read<AppStatusCubit>().storeUrl;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _rate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = SeenStrings.of(context);
    final url = _storeUrl(context);
    final ok = url != null && await (launcher ?? InjectionContainer.instance.storeLauncher).open(url);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.storeUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final year = (now ?? DateTime.now()).year;
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: s.aboutRow),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
                  children: [
                    Center(
                      child: ExcludeSemantics(
                        child: SvgPicture.asset(SeenVectors.logoVertical, width: 83, height: 144),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<AppVersionInfo>(
                      future: versionLoader(),
                      builder: (context, snap) => Text(
                        snap.hasData ? s.versionWithBuild(snap.data!.version, snap.data!.build) : '',
                        textAlign: TextAlign.center,
                        style: t.label.copyWith(color: c.inkSecondary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: const BorderRadius.all(SeenRadius.r22),
                        border: Border.all(color: c.border),
                        boxShadow: SeenShadows.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            _LinkRow(
                              title: s.termsTitle,
                              onTap: () => Navigator.of(context).push(LegalDocumentScreen.route(LegalKind.terms)),
                            ),
                            _LinkRow(
                              title: s.privacyTitle,
                              onTap: () => Navigator.of(context).push(LegalDocumentScreen.route(LegalKind.privacy)),
                            ),
                            _LinkRow(
                              title: s.openSourceLicences,
                              onTap: () => showLicensePage(
                                context: context,
                                applicationName: s.appName,
                                applicationIcon: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SvgPicture.asset(SeenVectors.logoVertical, width: 48),
                                ),
                              ),
                            ),
                            _LinkRow(title: s.rateApp, last: true, onTap: () => _rate(context)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.copyrightLine(year),
                      textAlign: TextAlign.center,
                      style: t.caption.copyWith(color: c.inkMuted),
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.onTap, this.last = false});

  final String title;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(child: Text(title, style: t.body)),
                Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
