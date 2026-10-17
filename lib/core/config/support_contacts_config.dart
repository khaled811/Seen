import 'package:flutter/foundation.dart' show kDebugMode;

import '../../features/support/domain/entities/support_contacts.dart';

/// The support channels shown before sign-in (Figma SUP-05). They are build-time
/// settings, not hard-coded numbers:
///
///     flutter build apk --dart-define=SUPPORT_WHATSAPP="+967 …" \
///       --dart-define=SUPPORT_PHONE="+967 …" \
///       --dart-define=SUPPORT_EMAIL="…" --dart-define=SUPPORT_HOURS="…"
///
/// With none set, release builds show the "available after sign-in" note;
/// debug builds show obvious placeholders so the sheet can be looked at.
abstract final class SupportContactsConfig {
  static const _whatsapp = String.fromEnvironment('SUPPORT_WHATSAPP');
  static const _phone = String.fromEnvironment('SUPPORT_PHONE');
  static const _email = String.fromEnvironment('SUPPORT_EMAIL');
  static const _hours = String.fromEnvironment('SUPPORT_HOURS');

  static SupportContacts get current {
    const configured = SupportContacts(
      whatsapp: _whatsapp == '' ? null : _whatsapp,
      phone: _phone == '' ? null : _phone,
      email: _email == '' ? null : _email,
      hours: _hours == '' ? null : _hours,
    );
    if (configured.hasChannels || !kDebugMode) return configured;
    return const SupportContacts(
      whatsapp: '+000 0 000 000 (debug)',
      phone: '+000 0 000 000 (debug)',
      email: 'support@example.invalid',
      hours: '8:00 – 22:00 (debug)',
    );
  }
}
