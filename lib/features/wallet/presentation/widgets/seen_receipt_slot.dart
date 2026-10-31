// The top-up receipt (Figma 12): the dropzone, then the picked file with its
// upload state and replace / remove, or the reason it was not taken. The file is
// sent as soon as it is picked and the request refers to it by id.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/network/file_upload_client.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart' show SeenTextLink;
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_thin_progress.dart';
import '../../../requests/domain/entities/missing_document.dart';
import '../../../requests/presentation/bloc/staged_attachment_cubit.dart';
import '../../../services/presentation/widgets/seen_attachment_slot.dart' show showAttachmentSourceSheet;
import '../../../system_status/presentation/widgets/permission_denied_sheet.dart';

class SeenReceiptSlot extends StatelessWidget {
  const SeenReceiptSlot({super.key, required this.title, required this.caption, this.emptyBuilder, this.attachedText, this.uploadingText});

  final String title;
  final String caption;

  /// What shows while nothing is picked, when not the standard dropzone (the ticket form keeps its own tile).
  final Widget Function(VoidCallback onTap)? emptyBuilder;

  /// Wording of the attached / uploading lines; the receipt's own by default.
  final String? attachedText;
  final String? uploadingText;

  Future<void> _choose(BuildContext context) async {
    final cubit = context.read<StagedAttachmentCubit>();
    final source = await showAttachmentSourceSheet(context);
    if (source != null) await cubit.pick(source);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<StagedAttachmentCubit, StagedAttachmentState>(
      // A permission refused for good opens the explanation (Figma SYS-07).
      listenWhen: (a, b) =>
          a.issue != b.issue &&
          (b.issue == StagedAttachmentIssue.cameraDenied || b.issue == StagedAttachmentIssue.photosDenied),
      listener: (context, state) async {
        final cubit = context.read<StagedAttachmentCubit>();
        final choice = await showPermissionDeniedSheet(
          context,
          permission: state.issue == StagedAttachmentIssue.cameraDenied ? DeniedPermission.camera : DeniedPermission.photos,
        );
        if (choice == PermissionSheetChoice.chooseFile) await cubit.pick(DocumentSource.file);
      },
      builder: (context, state) {
        final file = state.file;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file == null)
              (emptyBuilder?.call(() => _choose(context)) ?? SeenDropzone(title: title, caption: caption, onTap: () => _choose(context)))
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.all(SeenRadius.r14),
                  border: Border.all(color: c.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(SeenIcons.file, color: c.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(file.fileName, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${(file.sizeBytes / 1024).ceil()} KB', style: t.caption.copyWith(color: c.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (state.uploading) ...[
                        Text(uploadingText ?? l10n.topUpReceiptUploading, style: t.caption.copyWith(color: c.inkMuted)),
                        const SizedBox(height: 6),
                        SeenThinProgress(value: state.progress > 0 ? state.progress : null),
                      ] else ...[
                        if (state.isAttached) Text(attachedText ?? l10n.topUpReceiptAttached, style: t.caption.copyWith(color: c.inkMuted)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SeenTextLink(label: s.attachReplace, onTap: () => _choose(context)),
                            const SizedBox(width: 16),
                            SeenTextLink(label: s.attachRemove, onTap: () => context.read<StagedAttachmentCubit>().remove()),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (state.failure != null) ...[
              const SizedBox(height: 8),
              SeenInlineBanner(tone: SeenBannerTone.error, message: localizedFailureMessage(l10n, state.failure!)),
            ] else if (state.issue != null) ...[
              const SizedBox(height: 8),
              SeenInlineBanner(
                tone: SeenBannerTone.error,
                message: switch (state.issue!) {
                  StagedAttachmentIssue.tooLarge => s.attachTooLarge(UploadLimits.maxBytes ~/ (1024 * 1024)),
                  StagedAttachmentIssue.wrongType => s.attachBadType,
                  _ => s.attachUnavailable,
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
