// Traveler attachment slot (Figma BOOK-06): the dropzone, then the picked file with
// replace / remove, or the reason a pick was refused. Source choice is a sheet.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart' show SeenTextLink;
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../requests/domain/entities/missing_document.dart';
import '../bloc/traveler_attachment_cubit.dart';

Future<DocumentSource?> showAttachmentSourceSheet(BuildContext context) {
  final s = SeenStrings.of(context);
  return showSeenSheet<DocumentSource>(
    context: context,
    title: s.attachSourceTitle,
    subtitle: s.attachTypes,
    builder: (ctx) {
      final c = SeenColors.of(ctx);
      Widget row(IconData icon, String label, DocumentSource source) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: c.primary),
            title: Text(label),
            onTap: () => Navigator.of(ctx).pop(source),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(SeenIcons.camera, s.attachCamera, DocumentSource.camera),
          row(SeenIcons.image, s.attachGallery, DocumentSource.gallery),
          row(SeenIcons.file, s.attachFile, DocumentSource.file),
        ],
      );
    },
  );
}

class SeenAttachmentSlot extends StatelessWidget {
  const SeenAttachmentSlot({super.key, required this.travelerId, required this.title, required this.caption});

  final String travelerId;
  final String title;
  final String caption;

  Future<void> _choose(BuildContext context) async {
    final cubit = context.read<TravelerAttachmentCubit>();
    final source = await showAttachmentSourceSheet(context);
    if (source != null) await cubit.pick(travelerId, source);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return BlocBuilder<TravelerAttachmentCubit, TravelerAttachmentState>(
      buildWhen: (a, b) =>
          a.files[travelerId] != b.files[travelerId] || a.error != b.error || a.errorTravelerId != b.errorTravelerId,
      builder: (context, state) {
        final file = state.files[travelerId];
        final error = state.errorTravelerId == travelerId ? state.error : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file == null)
              SeenDropzone(title: title, caption: caption, onTap: () => _choose(context))
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
                                Text('${(file.sizeBytes / 1024).ceil()} KB',
                                    style: t.caption.copyWith(color: c.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.attachNotSent, style: t.caption.copyWith(color: c.inkMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SeenTextLink(label: s.attachReplace, onTap: () => _choose(context)),
                          const SizedBox(width: 16),
                          SeenTextLink(
                            label: s.attachRemove,
                            onTap: () => context.read<TravelerAttachmentCubit>().remove(travelerId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              SeenInlineBanner(
                tone: SeenBannerTone.error,
                message: switch (error) {
                  AttachmentError.tooLarge => s.attachTooLarge(attachmentMaxBytes ~/ (1024 * 1024)),
                  AttachmentError.wrongType => s.attachBadType,
                  AttachmentError.unavailable => s.attachUnavailable,
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
