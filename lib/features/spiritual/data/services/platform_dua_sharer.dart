import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/dua_sharer.dart';

/// The system share sheet through `share_plus`.
class PlatformDuaSharer implements DuaSharer {
  const PlatformDuaSharer();

  @override
  Future<bool> share({required String subject, required String text}) async {
    try {
      final result = await Share.share(text, subject: subject);
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }
}

/// The system clipboard.
class SystemTextClipboard implements TextClipboard {
  const SystemTextClipboard();

  @override
  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));
}
