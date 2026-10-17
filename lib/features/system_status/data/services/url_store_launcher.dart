import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/store_launcher.dart';

/// Opens the store link with `url_launcher` (only http/https links).
class UrlStoreLauncher implements StoreLauncher {
  const UrlStoreLauncher();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
