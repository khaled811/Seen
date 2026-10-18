import 'package:url_launcher/url_launcher.dart';

/// Opens a link with the system (browser / downloads); false = nothing could open it.
Future<bool> launchExternalUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    // No app can handle the link: the caller shows its own message.
    return false;
  }
}
