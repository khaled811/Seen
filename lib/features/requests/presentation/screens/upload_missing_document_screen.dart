import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/missing_document.dart';
import '../bloc/missing_document_bloc.dart';
import '../widgets/seen_deadline_card.dart';

/// "Upload the missing document" (Figma REQ-05 / REQ-05b): what the authority
/// asks for and why, the deadline, the three sources (file, gallery, camera),
/// then preview → send with progress, and the error / deadline-passed states.
/// Owns a [MissingDocumentBloc]; pops with `true` once the document was sent.
class UploadMissingDocumentScreen extends StatelessWidget {
  const UploadMissingDocumentScreen({
    super.key,
    required this.requestId,
    this.referenceId,
    this.onNewRequest,
    this.createBloc,
  });

  final String requestId;

  /// Shown under the title while the details load.
  final String? referenceId;

  /// "New request" on the deadline-passed banner; defaults to going back to the
  /// first route.
  final VoidCallback? onNewRequest;

  /// Test seam; defaults to the DI container.
  final MissingDocumentBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          (createBloc ?? InjectionContainer.instance.createMissingDocumentBloc)()..add(MissingDocumentStarted(requestId)),
      child: _View(requestId: requestId, referenceId: referenceId, onNewRequest: onNewRequest),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.requestId, this.referenceId, this.onNewRequest});

  final String requestId;
  final String? referenceId;
  final VoidCallback? onNewRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<MissingDocumentBloc, MissingDocumentState>(
      listenWhen: (previous, current) => !previous.submitted && current.submitted,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.uploadDone)));
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        body: SeenScreenBackground(
          washHeight: 320,
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<MissingDocumentBloc, MissingDocumentState>(
              builder: (context, state) {
                final bloc = context.read<MissingDocumentBloc>();
                final request = state.request;
                return Column(
                  children: [
                    SeenScreenHeader(
                      title: l10n.uploadDocTitle,
                      subtitle: request?.referenceId ?? referenceId,
                      onBack: state.uploading ? null : () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: switch (state.status) {
                        MissingDocumentStatus.loading => const Center(child: CircularProgressIndicator()),
                        MissingDocumentStatus.loadFailed => ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            children: [
                              SeenInlineBanner(
                                tone: SeenBannerTone.error,
                                message: l10n.uploadErrLoad,
                                actionLabel: l10n.uploadRetry,
                                onAction: () => bloc.add(MissingDocumentStarted(requestId)),
                              ),
                            ],
                          ),
                        MissingDocumentStatus.ready => _Body(request: request!, state: state, onNewRequest: onNewRequest),
                      },
                    ),
                    if (state.status == MissingDocumentStatus.ready) _ActionBar(state: state),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state});

  final MissingDocumentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<MissingDocumentBloc>();
    final hasFile = state.picked != null;
    return SeenActionBar(
      actions: [
        SeenButton(
          label: hasFile ? (state.uploading ? l10n.uploadUploading : l10n.uploadSend) : l10n.uploadAction,
          loading: state.uploading,
          expand: true,
          onPressed: (state.uploading || state.deadlinePassed)
              ? null
              : () => bloc.add(
                    hasFile ? const MissingDocumentSubmitted() : const MissingDocumentSourceChosen(DocumentSource.file),
                  ),
        ),
      ],
    );
  }
}

String _megabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb == mb.roundToDouble() ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
}

class _Body extends StatelessWidget {
  const _Body({required this.request, required this.state, this.onNewRequest});

  final MissingDocumentRequest request;
  final MissingDocumentState state;
  final VoidCallback? onNewRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<MissingDocumentBloc>();
    final issue = state.issue;
    final picked = state.picked;

    Widget? banner;
    if (issue != null) {
      banner = switch (issue.kind) {
        DocumentIssueKind.deadlinePassed => SeenInlineBanner(
            tone: SeenBannerTone.warn,
            message: l10n.uploadDeadlinePassed,
            actionLabel: l10n.uploadNewRequest,
            onAction: onNewRequest ?? () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        DocumentIssueKind.offline => SeenInlineBanner(
            tone: SeenBannerTone.error,
            message: l10n.uploadErrOffline,
            actionLabel: l10n.uploadRetry,
            onAction: () => bloc.add(const MissingDocumentSubmitted()),
          ),
        DocumentIssueKind.tooLarge =>
          SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.uploadErrTooLarge(_megabytes(request.maxBytes))),
        DocumentIssueKind.wrongType => SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.uploadErrWrongType),
        DocumentIssueKind.pickerUnavailable =>
          SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.uploadErrPicker),
        DocumentIssueKind.uploadFailed || DocumentIssueKind.loadFailed =>
          SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.uploadErrFailed),
      };
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (picked == null) ...[
          if (!state.deadlinePassed) ...[
            SeenDeadlineCard(
              amber: true,
              deadline: request.deadline,
              title: l10n.uploadDeadlineTitle,
              subtitle: l10n.uploadDeadlineSubtitle,
              expiredLabel: '00:00:00',
            ),
            const SizedBox(height: 16),
          ],
          _WhatAndWhy(request: request),
          const SizedBox(height: 16),
          _Sources(enabled: !state.deadlinePassed),
        ] else ...[
          _Preview(document: picked),
          const SizedBox(height: 14),
          if (!state.uploading)
            Row(
              children: [
                _TonalButton(label: l10n.uploadReplace, onTap: () => bloc.add(const MissingDocumentRemoved())),
                const SizedBox(width: 8),
                SeenTextLink(label: l10n.uploadRemove, onTap: () => bloc.add(const MissingDocumentRemoved())),
              ],
            ),
          if (state.uploading) _UploadProgress(progress: state.progress),
        ],
        if (banner != null) ...[const SizedBox(height: 14), banner],
      ],
    );
  }
}

class _WhatAndWhy extends StatelessWidget {
  const _WhatAndWhy({required this.request});

  final MissingDocumentRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final amber = SeenRequestStatus.actionRequired.colors;
    final formats = request.allowedExtensions.where((e) => e != 'jpeg').map((e) => e.toUpperCase()).join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: amber.bg, borderRadius: const BorderRadius.all(Radius.circular(13))),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: SeenSvgIcon(SeenVectors.missingDocTile, size: 25)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.documentTitle, style: t.title),
                      if (request.travelerName != null)
                        Text(
                          l10n.uploadTraveler(request.travelerName!),
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(l10n.uploadReason(request.reason), style: t.body.copyWith(color: c.inkSecondary)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tip(l10n.uploadTipFormats(formats)),
                _Tip(l10n.uploadTipSize(_megabytes(request.maxBytes))),
                _Tip(l10n.uploadTipFullPage),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.full)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: t.caption.copyWith(color: SeenBrand.violet)),
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<MissingDocumentBloc>();
    Widget src(String label, String asset, DocumentSource source) => Expanded(
          child: _SourceCard(
            label: label,
            asset: asset,
            onTap: enabled ? () => bloc.add(MissingDocumentSourceChosen(source)) : null,
          ),
        );
    return Row(
      children: [
        src(l10n.uploadSourceCamera, SeenVectors.sourceCamera, DocumentSource.camera),
        const SizedBox(width: 8),
        src(l10n.uploadSourceGallery, SeenVectors.sourceGallery, DocumentSource.gallery),
        const SizedBox(width: 8),
        src(l10n.uploadSourceFile, SeenVectors.sourceFile, DocumentSource.file),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.label, required this.asset, required this.onTap});

  final String label;
  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: SeenShadows.card, borderRadius: radius),
          child: Material(
            color: c.card,
            shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: SeenBrand.violet10,
                        borderRadius: BorderRadius.all(SeenRadius.r12),
                      ),
                      child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(asset, size: 22))),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: t.label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.document});

  final PickedDocument document;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeenBrand.violet05,
        borderRadius: const BorderRadius.all(SeenRadius.r20),
        border: Border.all(color: c.border),
      ),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SeenSvgIcon(SeenVectors.previewDoc, size: 44),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Directionality(
                textDirection: TextDirection.ltr, // file names never reorder
                child: Text(
                  '${document.fileName} · ${(document.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r14);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: SeenBrand.violet10,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text(label, style: t.label.copyWith(color: SeenBrand.violet))),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final percent = (progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.uploadUploading, style: t.label)),
                Text('$percent%', style: t.label.copyWith(color: SeenBrand.violet)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: const BorderRadius.all(SeenRadius.full),
              child: Stack(
                children: [
                  const SizedBox(height: 6, width: double.infinity, child: ColoredBox(color: SeenBrand.violet10)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.02, 1),
                    child: const SizedBox(
                      height: 6,
                      child: DecoratedBox(decoration: BoxDecoration(gradient: SeenBrand.gradientCta)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
