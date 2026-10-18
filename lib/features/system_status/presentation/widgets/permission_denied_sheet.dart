// Camera / photos permission refused for good (Figma SYS-07): explains why the app needs
// it, how to turn it back on, and offers a way to carry on without it (pick a file).
import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/services/app_settings_launcher.dart';

enum DeniedPermission { camera, photos }

enum PermissionSheetChoice { openedSettings, chooseFile }

/// Opens the sheet. "Open settings" opens the app's settings (and closes the sheet);
/// "Choose a file instead" resolves [PermissionSheetChoice.chooseFile] so the caller can
/// carry on with the file picker. Dismissing resolves null.
Future<PermissionSheetChoice?> showPermissionDeniedSheet(
  BuildContext context, {
  required DeniedPermission permission,
  AppSettingsLauncher? launcher,
}) {
  return showModalBottomSheet<PermissionSheetChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PermissionDeniedBody(permission: permission, launcher: launcher),
  );
}

class _PermissionDeniedBody extends StatelessWidget {
  const _PermissionDeniedBody({required this.permission, this.launcher});

  final DeniedPermission permission;
  final AppSettingsLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final camera = permission == DeniedPermission.camera;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(19))),
              child: SizedBox(width: 64, height: 64, child: Icon(camera ? SeenIcons.camera : SeenIcons.image, size: 36, color: SeenBrand.violet)),
            ),
          ),
          const SizedBox(height: 16),
          Text(camera ? s.cameraAllowTitle : s.photosAllowTitle, textAlign: TextAlign.center, style: t.h2),
          const SizedBox(height: 8),
          Text(camera ? s.cameraAllowBody : s.photosAllowBody,
              textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 16),
          SeenInlineBanner(tone: SeenBannerTone.warn, message: camera ? s.cameraDeniedBanner : s.photosDeniedBanner),
          const SizedBox(height: 16),
          SeenButton(
            label: s.openSettings,
            expand: true,
            onPressed: () async {
              final navigator = Navigator.of(context);
              await (launcher ?? InjectionContainer.instance.appSettingsLauncher).open();
              navigator.pop(PermissionSheetChoice.openedSettings);
            },
          ),
          const SizedBox(height: 8),
          SeenButton.ghost(
            label: s.chooseFileInstead,
            expand: true,
            onPressed: () => Navigator.of(context).pop(PermissionSheetChoice.chooseFile),
          ),
        ],
      ),
    );
  }
}
