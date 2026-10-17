// "Request documents" sheet (Figma REQ-12): the documents of each traveler with
// their status — issued, approved, in review — or a note when a traveler has
// none yet. Tapping a document opens it in the viewer (Figma REQ-11).
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_traveler_status.dart';
import '../screens/request_document_viewer_screen.dart';

Future<void> showTravelerDocumentsSheet(BuildContext context, RequestDetail detail) {
  final l10n = AppLocalizations.of(context)!;
  return showSeenSheet<void>(
    context: context,
    title: l10n.requestDocumentsOfRequestTitle,
    subtitle: SeenStrings.of(context).travelerCount(detail.travelers.length),
    builder: (_) => _TravelerDocuments(detail: detail),
  );
}

class _TravelerDocuments extends StatelessWidget {
  const _TravelerDocuments({required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = SeenType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final traveler in detail.travelers) ...[
          Text(traveler.name, style: t.label),
          const SizedBox(height: 12),
          if (traveler.documents.isEmpty)
            _EmptyNote(message: l10n.requestDocsTravelerEmpty)
          else
            for (final doc in traveler.documents) ...[
              _DocumentRow(detail: detail, document: doc),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.detail, required this.document});

  final RequestDetail detail;
  final TravelerDocument document;

  SeenRequestStatus? get _chip => switch (document.status) {
        TravelerDocumentStatus.issued => SeenRequestStatus.completed,
        TravelerDocumentStatus.approved => SeenRequestStatus.confirmed,
        TravelerDocumentStatus.inReview => SeenRequestStatus.underReview,
        TravelerDocumentStatus.unknown => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final chip = _chip;
    final url = document.url;
    final label = switch (document.status) {
      TravelerDocumentStatus.issued => l10n.requestDocStatusIssued,
      TravelerDocumentStatus.approved => l10n.requestDocStatusApproved,
      _ => l10n.requestDocStatusInReview,
    };
    return Semantics(
      button: url != null,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r14),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          // A document without a link yet (still being prepared) is not openable.
          onTap: url == null || url.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RequestDocumentViewerScreen(
                        detail: detail,
                        documentUrl: url,
                        documentName: document.name,
                      ),
                    ),
                  ),
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SeenSvgIcon(SeenVectors.previewDoc, size: 20, color: c.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(document.name, style: t.body, overflow: TextOverflow.ellipsis)),
                if (chip != null) ...[
                  const SizedBox(width: 8),
                  SeenStatusChip(status: chip, label: label),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final review = SeenRequestStatus.underReview.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: review.bg, borderRadius: const BorderRadius.all(SeenRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SeenSvgIcon(SeenVectors.notifReview, size: 20, color: review.fg),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: t.label.copyWith(color: review.fg))),
          ],
        ),
      ),
    );
  }
}
