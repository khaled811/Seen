import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum RequestDocumentKind {
  pdf,
  image;

  /// From a file name or URL; anything that is not an image is treated as PDF
  /// (the only other document the backend issues).
  static RequestDocumentKind fromName(String name) {
    final clean = name.split('?').first.toLowerCase();
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      if (clean.endsWith(ext)) return RequestDocumentKind.image;
    }
    return RequestDocumentKind.pdf;
  }
}

/// A downloaded request document, held in memory only. Pure Dart.
class RequestDocumentFile extends Equatable {
  const RequestDocumentFile({required this.fileName, required this.kind, required this.bytes});

  final String fileName;
  final RequestDocumentKind kind;
  final Uint8List bytes;

  @override
  List<Object?> get props => [fileName, kind, bytes.length];
}
