import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_document.dart';
import '../../domain/services/pdf_page_renderer.dart';
import '../bloc/document_viewer_bloc.dart';
import '../widgets/document_pages_view.dart';
import '../widgets/request_status_seen_mapping.dart';

typedef DocumentPagesBuilder = Widget Function(
  BuildContext context,
  Uint8List bytes,
  RequestDocumentKind kind,
  void Function(int page, int total) onPageChanged,
  VoidCallback onLoadFailed,
);

/// Document viewer (Figma REQ-11 / REQ-11b) for a request's output document:
/// pages with zoom and thumbnails, share and download; or "not ready yet" while
/// the request has no document, or "could not open" with retry / report.
class RequestDocumentViewerScreen extends StatelessWidget {
  const RequestDocumentViewerScreen({
    super.key,
    required this.detail,
    this.createBloc,
    this.pagesBuilder,
    this.createPdfRenderer,
    this.documentUrl,
    this.documentName,
  }) : referenceLabel = null;

  /// Any single file (e.g. a top-up receipt, Figma WAL-02), not tied to a request.
  const RequestDocumentViewerScreen.file({
    super.key,
    required String url,
    required String name,
    this.referenceLabel,
    this.createBloc,
    this.pagesBuilder,
    this.createPdfRenderer,
  })  : detail = null,
        documentUrl = url,
        documentName = name;

  final RequestDetail? detail;

  /// The subtitle of a [RequestDocumentViewerScreen.file] viewer.
  final String? referenceLabel;

  /// A specific traveler document to open (Figma REQ-12) instead of the
  /// request's output document.
  final String? documentUrl;
  final String? documentName;

  /// Test seams; default to the DI container and [DocumentPagesView].
  final DocumentViewerBloc Function()? createBloc;
  final DocumentPagesBuilder? pagesBuilder;

  /// The PDF engine; none ships yet, so PDFs show the download / share card.
  /// Defaults to the DI container (null today).
  final PdfPageRenderer Function()? createPdfRenderer;

  String? get _url {
    final own = documentUrl;
    if (own != null && own.isNotEmpty) return own;
    final request = detail;
    final url = request?.outputDocumentUrl;
    return request != null && request.hasOutput && url != null && url.isNotEmpty ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return _NotReadyScreen(detail: detail!);
    return BlocProvider(
      create: (_) => (createBloc ?? InjectionContainer.instance.createDocumentViewerBloc)()
        ..add(DocumentViewerLoadRequested(url)),
      child: _ViewerScreen(
        reference: detail?.referenceId ?? referenceLabel ?? '',
        serviceName: detail?.serviceName ?? '',
        url: url,
        name: documentName,
        pagesBuilder: pagesBuilder,
        createPdfRenderer: createPdfRenderer ?? InjectionContainer.instance.createPdfPageRenderer,
      ),
    );
  }
}

String _fileName(String serviceName, String url) {
  final path = url.split('?').first;
  final dot = path.lastIndexOf('.');
  final ext = dot > path.lastIndexOf('/') && dot >= 0 ? path.substring(dot) : '.pdf';
  return '$serviceName$ext';
}

void _openSupport(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));

class _ViewerScreen extends StatefulWidget {
  const _ViewerScreen({
    required this.reference,
    required this.serviceName,
    required this.url,
    this.name,
    this.pagesBuilder,
    this.createPdfRenderer,
  });

  final String reference;
  final String serviceName;
  final String url;
  final String? name;
  final DocumentPagesBuilder? pagesBuilder;
  final PdfPageRenderer Function()? createPdfRenderer;

  @override
  State<_ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<_ViewerScreen> {
  int _page = 0;
  int _total = 1;
  // The pages view could not decode the bytes (corrupt file).
  bool _undecodable = false;

  late final String _name = widget.name ?? _fileName(widget.serviceName, widget.url);

  void _onPage(int page, int total) {
    // Called from the pages view's post-frame / async callbacks.
    if (!mounted || (page == _page && total == _total)) return;
    setState(() {
      _page = page;
      _total = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final kind = RequestDocumentKind.fromName(widget.url);
    return BlocListener<DocumentViewerBloc, DocumentViewerState>(
      listenWhen: (previous, current) => previous.outcomeSeq != current.outcomeSeq && current.outcome != null,
      listener: (context, state) {
        final message = switch (state.outcome!) {
          DocumentExportOutcome.saved => l10n.viewerSaved,
          DocumentExportOutcome.saveFailed => l10n.viewerSaveFailed,
          DocumentExportOutcome.shareFailed => l10n.viewerShareFailed,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: BlocBuilder<DocumentViewerBloc, DocumentViewerState>(
        builder: (context, state) {
          final bloc = context.read<DocumentViewerBloc>();
          final ready = state.status == DocumentViewerStatus.ready && !_undecodable;
          final failed = state.status == DocumentViewerStatus.failed || _undecodable;
          return Scaffold(
            backgroundColor: SeenBrand.violet05,
            body: SeenScreenBackground(
              washHeight: 320,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SeenScreenHeader(
                      title: ready ? _name : l10n.requestDocumentsTitle,
                      subtitle: ready
                          ? l10n.viewerPageOf(s.numeral(_page + 1), s.numeral(_total))
                          : widget.reference,
                      trailing: ready
                          ? _RoundSvgButton(
                              asset: SeenVectors.viewerShare,
                              label: l10n.viewerShare,
                              onTap: state.exporting ? null : () => bloc.add(DocumentViewerShareRequested(_name)),
                            )
                          : null,
                    ),
                    Expanded(
                      child: switch ((ready, failed)) {
                        // No PDF engine installed: say so, download / share still work.
                        (true, _) when kind == RequestDocumentKind.pdf &&
                            widget.pagesBuilder == null &&
                            widget.createPdfRenderer == null =>
                          ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            children: [
                              _MessageCard(
                                tint: SeenBrand.violet10,
                                icon: SeenVectors.previewDoc,
                                title: l10n.viewerPdfUnavailableTitle,
                                body: l10n.viewerPdfUnavailableBody,
                                actions: const [],
                              ),
                            ],
                          ),
                        (true, _) => (widget.pagesBuilder ?? _defaultPages)(
                            context,
                            state.bytes!,
                            kind,
                            _onPage,
                            () => setState(() => _undecodable = true),
                          ),
                        (_, true) => ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            children: [
                              _MessageCard(
                                tint: SeenRequestStatus.rejected.colors.bg,
                                icon: SeenVectors.viewerAlert,
                                title: l10n.viewerFailedTitle,
                                body: l10n.viewerFailedBody,
                                actions: [
                                  _TonalButton(
                                    label: l10n.uploadRetry,
                                    onTap: () {
                                      setState(() => _undecodable = false);
                                      bloc.add(DocumentViewerLoadRequested(widget.url));
                                    },
                                  ),
                                  SeenTextLink(label: l10n.viewerReportSupport, onTap: () => _openSupport(context)),
                                ],
                              ),
                            ],
                          ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
                    ),
                    if (ready)
                      DecoratedBox(
                        decoration: BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SeenButton(
                                    label: state.exporting ? l10n.loading : l10n.viewerDownload,
                                    loading: state.exporting,
                                    expand: true,
                                    onPressed: state.exporting ? null : () => bloc.add(DocumentViewerSaveRequested(_name)),
                                  ),
                                ),
                                const SizedBox(width: SeenSpace.s3),
                                Expanded(
                                  child: SeenButton.secondary(
                                    label: l10n.viewerShare,
                                    expand: true,
                                    onPressed: state.exporting ? null : () => bloc.add(DocumentViewerShareRequested(_name)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _defaultPages(
    BuildContext context,
    Uint8List bytes,
    RequestDocumentKind kind,
    void Function(int, int) onPageChanged,
    VoidCallback onLoadFailed,
  ) =>
      DocumentPagesView(
        bytes: bytes,
        kind: kind,
        onPageChanged: onPageChanged,
        onLoadFailed: onLoadFailed,
        createPdfRenderer: widget.createPdfRenderer,
      );
}

/// REQ-11b "not ready yet": the request has no document (yet).
class _NotReadyScreen extends StatelessWidget {
  const _NotReadyScreen({required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final status = detail.status.toSeenRequestStatus(slaDeadline: detail.slaDeadline);
    final progress = detail.status.progress;
    final chipLabel = progress.isVisible
        ? '${s.requestStatus(status)} · ${s.stepOf(progress.step, progress.total)}'
        : s.requestStatus(status);
    return Scaffold(
      body: SeenScreenBackground(
        washHeight: 320,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: l10n.requestDocumentsTitle, subtitle: detail.referenceId),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: [
                    _MessageCard(
                      tint: SeenRequestStatus.withAuthority.colors.bg,
                      icon: SeenVectors.viewerClock,
                      title: l10n.viewerNotReadyTitle,
                      body: l10n.viewerNotReadyBody,
                      actions: [SeenStatusChip(status: status, label: chipLabel)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.tint,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final Color tint;
  final String icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
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
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: tint, borderRadius: const BorderRadius.all(Radius.circular(16))),
              child: SizedBox(width: 52, height: 52, child: Center(child: SeenSvgIcon(icon, size: 29))),
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: t.title),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
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

class _RoundSvgButton extends StatelessWidget {
  const _RoundSvgButton({required this.asset, required this.label, required this.onTap});

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: SeenShadows.card),
        child: Material(
          color: c.card,
          shape: CircleBorder(side: BorderSide(color: c.border)),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(width: 44, height: 44, child: Center(child: SeenSvgIcon(asset, size: 22))),
          ),
        ),
      ),
    );
  }
}
