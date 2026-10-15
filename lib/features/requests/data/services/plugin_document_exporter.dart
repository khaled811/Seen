import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error/failure.dart';
import '../../domain/services/document_exporter.dart';

/// [DocumentExporter]: "save" opens the system save dialog (`file_picker`),
/// "share" writes a temporary file and opens the share sheet (`share_plus`).
/// Nothing is kept by the app after either returns (the temp file is deleted).
class PluginDocumentExporter implements DocumentExporter {
  @override
  Future<Either<Failure, bool>> save(String fileName, Uint8List bytes) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: fileName,
        fileName: fileName,
        bytes: bytes,
      );
      return Right(path != null);
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'EXPORT_FAILED'));
    }
  }

  @override
  Future<Either<Failure, bool>> share(String fileName, Uint8List bytes) async {
    File? temp;
    try {
      final dir = await getTemporaryDirectory();
      temp = File('${dir.path}${Platform.pathSeparator}$fileName');
      await temp.writeAsBytes(bytes, flush: true);
      final result = await Share.shareXFiles([XFile(temp.path)]);
      return Right(result.status != ShareResultStatus.dismissed);
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'EXPORT_FAILED'));
    } finally {
      try {
        await temp?.delete();
      } catch (_) {}
    }
  }
}
