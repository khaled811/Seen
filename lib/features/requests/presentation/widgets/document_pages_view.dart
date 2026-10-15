import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/request_document.dart';
import '../../domain/services/pdf_page_renderer.dart';

/// The page area of the document viewer (Figma REQ-11): the current page on a
/// white card with a zoom pill (− 100% +; pinch also works) and, for several
/// pages, a thumbnail strip. PDFs are rendered page by page through a
/// [PdfPageRenderer]; an image is one page.
///
/// Owns the renderer it creates, the zoom controller and the rendered-page
/// cache; all released in [dispose]. Reports the current page to [onPageChanged].
class DocumentPagesView extends StatefulWidget {
  const DocumentPagesView({
    super.key,
    required this.bytes,
    required this.kind,
    required this.onPageChanged,
    required this.onLoadFailed,
    this.createPdfRenderer,
  });

  final Uint8List bytes;
  final RequestDocumentKind kind;

  /// Creates the PDF engine; required to show a PDF.
  final PdfPageRenderer Function()? createPdfRenderer;

  /// (zero-based page, total pages).
  final void Function(int page, int total) onPageChanged;

  /// The file could not be opened (corrupt, not a PDF).
  final VoidCallback onLoadFailed;

  @override
  State<DocumentPagesView> createState() => _DocumentPagesViewState();
}

class _DocumentPagesViewState extends State<DocumentPagesView> {
  static const _zoomSteps = [1.0, 1.5, 2.0, 3.0];

  final _zoom = TransformationController();
  PdfPageRenderer? _renderer;
  int _pages = 1;
  int _page = 0;
  // Rendered pages by (index, thumbnail?) so scrolling back is free.
  final _rendered = <(int, bool), Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    if (widget.kind == RequestDocumentKind.pdf) {
      _openPdf();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPageChanged(0, 1));
    }
  }

  Future<void> _openPdf() async {
    final create = widget.createPdfRenderer;
    if (create == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoadFailed());
      return;
    }
    final renderer = create();
    try {
      final count = await renderer.open(widget.bytes);
      if (!mounted) {
        await renderer.close();
        return;
      }
      setState(() {
        _renderer = renderer;
        _pages = count;
      });
      widget.onPageChanged(0, _pages);
    } catch (_) {
      await renderer.close();
      if (mounted) widget.onLoadFailed();
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _renderer?.close();
    super.dispose();
  }

  Future<Uint8List?> _render(int index, {required bool thumb}) {
    return _rendered.putIfAbsent((index, thumb), () async {
      final renderer = _renderer;
      if (renderer == null) return null;
      return renderer.renderPage(index, scale: thumb ? 0.3 : 2.0);
    });
  }

  void _select(int index) {
    if (index == _page) return;
    setState(() => _page = index);
    _zoom.value = Matrix4.identity();
    widget.onPageChanged(index, _pages);
  }

  void _setZoom(double z, Size viewport) {
    // Scale about the centre of the viewport.
    _zoom.value = Matrix4.identity()
      ..translate(viewport.width * (1 - z) / 2, viewport.height * (1 - z) / 2)
      ..scale(z);
  }

  void _step(int direction, Size viewport) {
    final current = _zoom.value.getMaxScaleOnAxis();
    var i = _zoomSteps.indexWhere((s) => s >= current - 0.01);
    if (i < 0) i = _zoomSteps.length - 1;
    _setZoom(_zoomSteps[(i + direction).clamp(0, _zoomSteps.length - 1)], viewport);
  }

  Widget _pageImage(int index) {
    if (widget.kind == RequestDocumentKind.image) {
      return Image.memory(
        widget.bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoadFailed());
          return const SizedBox.shrink();
        },
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _render(index, thumb: false),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        return Image.memory(data, fit: BoxFit.contain);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: const BorderRadius.all(SeenRadius.lg),
                          border: Border.all(color: c.borderStrong),
                          boxShadow: SeenShadows.stickyBar,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(SeenRadius.lg),
                          child: InteractiveViewer(
                            transformationController: _zoom,
                            minScale: 1,
                            maxScale: 4,
                            child: SizedBox.expand(child: _pageImage(_page)),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: -6,
                      bottom: 12,
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: _zoom,
                        builder: (context, matrix, _) {
                          final percent = (matrix.getMaxScaleOnAxis() * 100).round();
                          Widget glyph(String s, VoidCallback onTap, String label) => Semantics(
                                button: true,
                                label: label,
                                excludeSemantics: true,
                                child: InkWell(
                                  onTap: onTap,
                                  customBorder: const CircleBorder(),
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Center(child: Text(s, style: t.h2.copyWith(color: c.inkSecondary))),
                                  ),
                                ),
                              );
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: const BorderRadius.all(SeenRadius.full),
                              border: Border.all(color: c.border),
                              boxShadow: SeenShadows.card,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    glyph('−', () => _step(-1, viewport), '−'),
                                    Text('$percent%', style: t.label),
                                    glyph('+', () => _step(1, viewport), '+'),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (_pages > 1) _Thumbs(count: _pages, selected: _page, onSelect: _select, thumb: (i) => _render(i, thumb: true)),
        if (_pages <= 1) const SizedBox(height: 16),
      ],
    );
  }
}

class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.count, required this.selected, required this.onSelect, required this.thumb});

  final int count;
  final int selected;
  final ValueChanged<int> onSelect;
  final Future<Uint8List?> Function(int index) thumb;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = i == selected;
          return Semantics(
            button: true,
            selected: active,
            label: '${i + 1}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.all(SeenRadius.sm),
                  border: Border.all(color: active ? SeenBrand.violet : c.border, width: active ? 2 : 1),
                ),
                child: SizedBox(
                  width: 48,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(SeenRadius.sm),
                    child: FutureBuilder<Uint8List?>(
                      future: thumb(i),
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        if (data != null) return Image.memory(data, fit: BoxFit.cover);
                        return Center(child: Text('${i + 1}', style: t.caption.copyWith(color: c.inkMuted)));
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
