import 'package:flutter/services.dart' show PlatformException;
import 'package:fpdart/fpdart.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../../domain/services/passport_photo_picker.dart';

/// [PassportPhotoPicker] over `image_picker`. The photo is scaled down to at most 2000 px on its
/// long side and re-encoded (quality 80) by the plugin, which keeps it well under 2 MB; the path
/// points at the plugin's temporary file, which the reading deletes.
class PluginPassportPhotoPicker implements PassportPhotoPicker {
  PluginPassportPhotoPicker({ImagePicker? imagePicker}) : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<Either<Failure, PassportPhoto?>> pick(PassportPhotoSource source) async {
    try {
      final image = await _images.pickImage(
        source: source == PassportPhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 80,
      );
      return Right(image == null ? null : PassportPhoto(path: image.path, fileName: image.name));
    } on PlatformException catch (e) {
      final code = switch (e.code) {
        'camera_access_denied' => PassportPhotoPicker.cameraDeniedCode,
        'photo_access_denied' => PassportPhotoPicker.photosDeniedCode,
        _ => 'PICKER_UNAVAILABLE',
      };
      return Left(ServerFailure(e.toString(), code: code));
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'PICKER_UNAVAILABLE'));
    }
  }
}
