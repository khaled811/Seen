import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/report.dart';

/// Running and exporting an agency report (`runAgentReport`, `exportAgentReport`); both need the
/// `report.create` permission, the export also `data.export`. Nothing is cached or kept.
abstract interface class ReportsRepository {
  Future<Either<Failure, ReportData>> run(ReportRequest request);

  /// The file as the server builds it (csv, xlsx or pdf). More than 5,000 rows is refused
  /// (`report_too_large`).
  Future<Either<Failure, ReportFile>> export(ReportRequest request, ReportFormat format);
}
