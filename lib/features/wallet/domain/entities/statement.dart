/// The file format of an exported statement (Figma WAL-06). The wire value is a
/// placeholder contract (docs/BACKEND_MIGRATION_GAPS.md, section 24).
enum StatementFormat {
  pdf('PDF', 'pdf'),
  excel('XLSX', 'xlsx');

  const StatementFormat(this.wire, this.extension);

  final String wire;
  final String extension;
}

/// A generated statement the app downloads from [url].
class StatementFile {
  const StatementFile({required this.url, required this.fileName});

  final String url;
  final String fileName;
}
