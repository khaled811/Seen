import 'dart:typed_data';

/// The formats an account statement can be exported in. The API offers a PDF
/// (`accountStatementPdf`); there is no spreadsheet export of the statement.
enum StatementFormat {
  pdf('PDF', 'pdf');

  const StatementFormat(this.wire, this.extension);

  final String wire;
  final String extension;
}

/// A generated statement, ready to save or share. The server returns the file
/// itself (base64), so nothing is downloaded from a link and nothing is cached.
class StatementFile {
  const StatementFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
