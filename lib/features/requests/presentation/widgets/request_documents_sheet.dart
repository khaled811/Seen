// "View documents" sheet for a request. The backend currently supplies at most
// one output document URL (approvals, once the request is completed) and no
// in-app viewer exists, so the sheet lists what is available and lets the user
// copy the link; with nothing available it says when documents will appear.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/request_detail.dart';

Future<void> showRequestDocumentsSheet(BuildContext context, RequestDetail detail) {
  final l10n = AppLocalizations.of(context)!;
  return showSeenSheet<void>(
    context: context,
    title: l10n.requestDocumentsTitle,
    builder: (sheetContext) => _DocumentsList(url: detail.hasOutput ? detail.outputDocumentUrl : null),
  );
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final link = url;

    if (link == null || link.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SeenSpace.s4),
        child: Text(
          l10n.requestDocumentsEmpty,
          textAlign: TextAlign.center,
          style: type.body.copyWith(color: c.inkSecondary),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r18),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SeenSpace.s3),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: c.primarySoft, borderRadius: const BorderRadius.all(SeenRadius.r14)),
              child: SizedBox(width: 40, height: 40, child: Icon(SeenIcons.file, size: 22, color: c.primary)),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.requestDocumentsApprovals, style: type.bodyStrong),
                  Text(l10n.requestDocumentsReady, style: type.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            SeenButton.secondary(
              label: l10n.requestDocumentsCopyLink,
              size: SeenButtonSize.small,
              icon: SeenIcons.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l10n.requestDocumentsLinkCopied)));
              },
            ),
          ],
        ),
      ),
    );
  }
}
