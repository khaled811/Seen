import 'dart:typed_data';

/// Renders the pages of one PDF to PNG bytes. One instance per opened
/// document; the owner must call [close].
///
/// No implementation ships yet: the PDF engine plugin (e.g. `pdfx`) is a heavy
/// native dependency that has not been added (docs/BACKEND_MIGRATION_GAPS.md,
/// section 13). The viewer is complete without it for images, and falls back to
/// a download / share card for PDFs.
abstract interface class PdfPageRenderer {
  /// Opens [bytes]; returns the page count. Throws if it is not a valid PDF.
  Future<int> open(Uint8List bytes);

  /// PNG of the zero-based [index] page at [scale] times its natural size.
  Future<Uint8List?> renderPage(int index, {required double scale});

  Future<void> close();
}
