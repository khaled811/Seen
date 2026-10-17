// "Contact support" before sign-in (Figma SUP-05): WhatsApp, a call and e-mail.
// A row opens WhatsApp, the dialer or the mail app; when the phone has nothing
// to handle it, the row copies its number / address instead and says so.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/config/support_contacts_config.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../data/services/url_contact_launcher.dart';
import '../../domain/entities/support_contacts.dart';
import '../../domain/services/contact_launcher.dart';

/// Opens the sheet. [contacts] defaults to [SupportContactsConfig.current].
Future<void> showContactSupportSheet(
  BuildContext context, {
  SupportContacts? contacts,
  ContactLauncher launcher = const UrlContactLauncher(),
}) {
  final l10n = AppLocalizations.of(context)!;
  final shown = contacts ?? SupportContactsConfig.current;
  final hours = shown.hours;
  // Messages that outlive the sheet go through the screen below it.
  final messenger = ScaffoldMessenger.of(context);
  return showSeenSheet<void>(
    context: context,
    title: l10n.contactSupportTitle,
    subtitle: hours == null || hours.trim().isEmpty ? null : hours,
    builder: (_) => _Options(contacts: shown, messenger: messenger, launcher: launcher),
  );
}

class _Options extends StatelessWidget {
  const _Options({required this.contacts, required this.messenger, required this.launcher});

  final SupportContacts contacts;
  final ScaffoldMessengerState messenger;
  final ContactLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    if (!contacts.hasChannels) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SeenSpace.s4),
        child: Text(
          l10n.agencyPendingSupportNote,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: c.inkSecondary),
        ),
      );
    }
    final rows = [
      if (_has(contacts.whatsapp))
        (SeenVectors.iconChat, l10n.contactSupportWhatsapp, contacts.whatsapp!, l10n.contactSupportCopiedNumber, ContactChannel.whatsapp),
      if (_has(contacts.phone))
        (SeenVectors.accountSupport, l10n.contactSupportCall, contacts.phone!, l10n.contactSupportCopiedNumber, ContactChannel.phone),
      if (_has(contacts.email))
        (SeenVectors.accountDocument, l10n.contactSupportEmail, contacts.email!, l10n.contactSupportCopiedEmail, ContactChannel.email),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _OptionRow(
                icon: rows[i].$1,
                title: rows[i].$2,
                value: rows[i].$3,
                onTap: () async {
                  if (await launcher.open(rows[i].$5, rows[i].$3)) return;
                  // Nothing on this phone handles it: give the value to paste instead.
                  await Clipboard.setData(ClipboardData(text: rows[i].$3));
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(rows[i].$4)));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.icon, required this.title, required this.value, required this.onTap});

  final String icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: '$title $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
                child: SizedBox(width: 36, height: 36, child: Center(child: SeenSvgIcon(icon, size: 20, color: c.primary))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.body.copyWith(color: c.ink)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(value, style: t.caption.copyWith(color: c.inkMuted)),
                    ),
                  ],
                ),
              ),
              Icon(SeenIcons.forward(context), size: 18, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
