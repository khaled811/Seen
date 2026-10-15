import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import 'document_file_remote_data_source.dart';

/// DEBUG ONLY: answers `mock://` document URLs (the debug requests use them)
/// with a generated two-page PDF so the viewer can be tried before the backend
/// serves files. A URL containing `broken` fails, to see the failure state.
/// `kDebugMode` is a compile-time constant, so release builds drop the branch.
class DebugFallbackDocumentFileRemoteDataSource implements DocumentFileRemoteDataSource {
  DebugFallbackDocumentFileRemoteDataSource(this._real);

  final DocumentFileRemoteDataSource _real;

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) async {
    if (kDebugMode && url.startsWith('mock://')) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (url.contains('broken')) return const Left(NetworkFailure('No connection.'));
      return Right(_demoPdf());
    }
    return _real.fetch(url);
  }

  /// A valid PDF with two pages, built with correct xref offsets.
  static Uint8List _demoPdf() {
    String stream(String text) => 'BT /F1 18 Tf 30 360 Td ($text) Tj ET';
    final contents = [stream('E-VISA  (page 1 of 2)'), stream('E-VISA  (page 2 of 2)')];
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [4 0 R 6 0 R] /Count 2 >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 595] /Resources << /Font << /F1 3 0 R >> >> /Contents 5 0 R >>',
      '<< /Length ${contents[0].length} >>\nstream\n${contents[0]}\nendstream',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 595] /Resources << /Font << /F1 3 0 R >> >> /Contents 7 0 R >>',
      '<< /Length ${contents[1].length} >>\nstream\n${contents[1]}\nendstream',
    ];
    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = out.length;
    out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    out.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    return Uint8List.fromList(latin1.encode(out.toString()));
  }
}
