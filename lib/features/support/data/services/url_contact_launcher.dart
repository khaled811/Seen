import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/contact_launcher.dart';

/// Opens a support channel with `url_launcher`.
class UrlContactLauncher implements ContactLauncher {
  const UrlContactLauncher();

  @override
  Future<bool> open(ContactChannel channel, String value) async {
    try {
      return await launchUrl(contactUri(channel, value), mode: LaunchMode.externalApplication);
    } catch (_) {
      // A platform error is the same as "no app for it": the sheet copies instead.
      return false;
    }
  }
}
