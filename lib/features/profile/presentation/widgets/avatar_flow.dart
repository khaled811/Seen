// Changing the profile photo (design/gaps PROF-02, PROF-03): the options sheet, picking, the
// checks before anything is sent, the crop, and the card that shows progress and errors.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../system_status/presentation/widgets/permission_denied_sheet.dart';
import '../../domain/entities/avatar.dart';
import '../../domain/services/avatar_picker.dart';
import '../bloc/avatar_cubit.dart';
import '../screens/avatar_crop_screen.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';

enum _Choice { camera, gallery, remove }

/// Runs the whole flow: sheet -> pick -> checks -> crop -> upload. [cubit], [picker] and [crop]
/// are test seams; they default to the app's own.
Future<void> changeProfilePhoto(
  BuildContext context, {
  AvatarCubit? cubit,
  AvatarPicker? picker,
  Future<AvatarCropResult?> Function(BuildContext context, PickedAvatar picked)? crop,
}) async {
  final avatars = cubit ?? InjectionContainer.instance.avatarCubit;
  final photos = picker ?? InjectionContainer.instance.avatarPicker;
  while (true) {
    if (!context.mounted) {
      return;
    }
    avatars.dismissIssue();
    final choice = await showSeenSheet<_Choice>(
      context: context,
      title: AppLocalizations.of(context)!.profSheetTitle,
      subtitle: AppLocalizations.of(context)!.profSheetSub,
      builder: (_) => _Options(hasPhoto: avatars.state.url != null),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    if (choice == _Choice.remove) {
      await avatars.remove();
      return;
    }
    final result = await photos.pick(choice == _Choice.camera ? AvatarSource.camera : AvatarSource.gallery);
    if (!context.mounted) {
      return;
    }
    final picked = result.fold<PickedAvatar?>((failure) {
      final issue = AvatarIssue.from(failure);
      avatars.report(issue);
      return null;
    }, (p) => p);
    final denied = avatars.state.issue?.kind;
    if (denied == AvatarIssueKind.cameraDenied || denied == AvatarIssueKind.photosDenied) {
      avatars.dismissIssue();
      await showPermissionDeniedSheet(context, permission: denied == AvatarIssueKind.cameraDenied ? DeniedPermission.camera : DeniedPermission.photos);
      return;
    }
    if (picked == null) {
      return;
    }
    if (picked.isTooLarge || !picked.isAllowedType) {
      avatars.reject(picked);
      return;
    }
    final cropped = await (crop ?? AvatarCropScreen.open)(context, picked);
    if (cropped == null) {
      return;
    }
    if (cropped.redo) {
      continue;
    }
    await avatars.upload(cropped.bytes!);
    return;
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionRow(icon: SeenIcons.camera, label: l10n.profTakePhoto, onTap: () => Navigator.of(context).pop(_Choice.camera)),
          _OptionRow(icon: SeenIcons.image, label: l10n.profChoosePhoto, onTap: () => Navigator.of(context).pop(_Choice.gallery)),
          if (hasPhoto)
            _OptionRow(
              icon: SeenIcons.trash,
              label: l10n.profDeletePhoto,
              color: SeenRequestStatus.rejected.colors.fg,
              onTap: () => Navigator.of(context).pop(_Choice.remove),
            ),
          const SizedBox(height: 8),
          SeenButton.secondary(label: l10n.commonCancel, expand: true, onPressed: () => Navigator.of(context).pop()),
          SizedBox(height: 0, child: ColoredBox(color: c.card)),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tint = color ?? c.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(SeenRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: color == null ? c.accentSoft : SeenRequestStatus.rejected.colors.bg, borderRadius: const BorderRadius.all(SeenRadius.r12)),
              child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: tint)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: type.body.copyWith(color: color ?? c.ink))),
          ],
        ),
      ),
    );
  }
}

/// Tells the person how the upload is going, and why a photo was refused (PROF-03). Draws
/// nothing when there is nothing to say. [cubit] is a test seam.
class AvatarStatusCard extends StatelessWidget {
  const AvatarStatusCard({super.key, this.cubit});

  final AvatarCubit? cubit;

  @override
  Widget build(BuildContext context) {
    AvatarCubit? avatars = cubit;
    if (avatars == null) {
      try {
        avatars = InjectionContainer.instance.avatarCubit;
      } on Object {
        return const SizedBox.shrink();
      }
    }
    return BlocConsumer<AvatarCubit, AvatarState>(
      bloc: avatars,
      listenWhen: (a, b) => b.event != null && a.event != b.event,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        showSeenToast(context, message: state.event == AvatarEvent.deleted ? l10n.profDeleted : l10n.profUpdated);
        avatars!.eventShown();
      },
      buildWhen: (a, b) => a.progress != b.progress || a.issue != b.issue || a.fileName != b.fileName,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        if (state.uploading) {
          return _UploadCard(name: state.fileName ?? '', size: state.sizeBytes ?? 0, fraction: state.progress ?? 0);
        }
        final issue = state.issue;
        if (issue == null) {
          return const SizedBox.shrink();
        }
        return switch (issue.kind) {
          AvatarIssueKind.tooLarge => _Banner('${l10n.profNotUploadedTitle}. ${SeenStrings.of(context).digits(l10n.profTooLarge(_mb(issue.sizeBytes ?? 0)))}'),
          AvatarIssueKind.wrongType => _Banner('${l10n.profNotUploadedTitle}. ${l10n.profWrongType}'),
          _ => _UploadCard(
              name: state.fileName ?? '',
              size: state.sizeBytes ?? 0,
              fraction: state.progress ?? 0,
              failed: true,
              onRetry: avatars!.retry,
            ),
        };
      },
    );
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SeenInlineBanner(tone: SeenBannerTone.error, message: message),
      );
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.name, required this.size, required this.fraction, this.failed = false, this.onRetry});

  final String name;
  final int size;
  final double fraction;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tone = failed ? SeenRequestStatus.rejected.colors : SeenRequestStatus.underReview.colors;
    final percent = (fraction * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                    child: SizedBox(width: 36, height: 36, child: Icon(SeenIcons.image, size: 20, color: tone.fg)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(textDirection: TextDirection.ltr, child: Text(name, style: type.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(
                          failed ? l10n.profUploadFailed : SeenStrings.of(context).digits(l10n.profUploadProgress(AvatarStatusCard._mb(size), percent)),
                          style: type.caption.copyWith(color: failed ? tone.fg : c.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (failed) SeenButton.outline(label: l10n.commonRetry, size: SeenButtonSize.small, onPressed: onRetry),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                child: LinearProgressIndicator(
                  value: failed ? 1 : fraction,
                  minHeight: 6,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(failed ? tone.fg : c.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
