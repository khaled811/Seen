import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:fpdart/fpdart.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/avatar.dart';
import '../../domain/services/avatar_picker.dart';

/// [AvatarPicker] over `image_picker`. Nothing is copied by the app: the path points at the
/// plugin's temporary file and is read once, when the photo is cropped.
class PluginAvatarPicker implements AvatarPicker {
  PluginAvatarPicker({ImagePicker? imagePicker}) : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<Either<Failure, PickedAvatar?>> pick(AvatarSource source) async {
    try {
      final image = await _images.pickImage(
        source: source == AvatarSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (image == null) {
        return const Right(null);
      }
      final size = await File(image.path).length();
      return Right(PickedAvatar(path: image.path, fileName: image.name, sizeBytes: size));
    } on PlatformException catch (e) {
      final code = switch (e.code) {
        'camera_access_denied' => AvatarIssue.cameraDeniedCode,
        'photo_access_denied' => AvatarIssue.photosDeniedCode,
        _ => 'PICKER_UNAVAILABLE',
      };
      return Left(ServerFailure(e.toString(), code: code));
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'PICKER_UNAVAILABLE'));
    }
  }
}
