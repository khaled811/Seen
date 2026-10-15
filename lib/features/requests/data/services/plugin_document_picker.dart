import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/missing_document.dart';
import '../../domain/services/document_picker.dart';

/// [DocumentPicker] over `file_picker` (files) and `image_picker` (gallery and
/// camera). Nothing is copied or cached by the app: the path points at the
/// plugin's temporary file and is read once, at upload time.
class PluginDocumentPicker implements DocumentPicker {
  PluginDocumentPicker({ImagePicker? imagePicker}) : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<Either<Failure, PickedDocument?>> pick(
    DocumentSource source, {
    required List<String> allowedExtensions,
  }) async {
    try {
      switch (source) {
        case DocumentSource.file:
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
            withData: false,
          );
          final file = result?.files.single;
          if (file == null || file.path == null) return const Right(null);
          return Right(PickedDocument(path: file.path!, fileName: file.name, sizeBytes: file.size));
        case DocumentSource.gallery:
        case DocumentSource.camera:
          final image = await _images.pickImage(
            source: source == DocumentSource.camera ? ImageSource.camera : ImageSource.gallery,
            maxWidth: 2400,
            imageQuality: 85,
          );
          if (image == null) return const Right(null);
          final size = await File(image.path).length();
          return Right(PickedDocument(path: image.path, fileName: image.name, sizeBytes: size));
      }
    } catch (e) {
      // Permission denied, no camera, plugin error: surfaced, never swallowed.
      return Left(ServerFailure(e.toString(), code: 'PICKER_UNAVAILABLE'));
    }
  }
}
