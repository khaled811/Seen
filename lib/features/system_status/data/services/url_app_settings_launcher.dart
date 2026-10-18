import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/app_settings_launcher.dart';

/// `app-settings:` opens the app's settings page on iOS. Android has no such link
/// without a settings plugin, so this answers false there.
class UrlAppSettingsLauncher implements AppSettingsLauncher {
  const UrlAppSettingsLauncher();

  @override
  Future<bool> open() async {
    try {
      return await launchUrl(Uri.parse('app-settings:'), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
