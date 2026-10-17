/// The ways to reach support (Figma SUP-05).
enum ContactChannel { whatsapp, phone, email }

/// Where a channel's value leads: WhatsApp's `wa.me` link, a `tel:` dial or a
/// `mailto:` message. Pure Dart. Phone numbers keep only digits (and a leading
/// `+`), so "+967 1 000 000" works as typed.
Uri contactUri(ContactChannel channel, String value) {
  final v = value.trim();
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  return switch (channel) {
    ContactChannel.whatsapp => Uri.parse('https://wa.me/$digits'),
    ContactChannel.phone => Uri.parse('tel:${v.startsWith('+') ? '+' : ''}$digits'),
    ContactChannel.email => Uri(scheme: 'mailto', path: v),
  };
}

/// Opens a channel in the phone's own app. `false` = nothing could handle it
/// (no WhatsApp, no dialer on a tablet, no mail app), so the caller can fall
/// back to copying the value.
abstract interface class ContactLauncher {
  Future<bool> open(ContactChannel channel, String value);
}
