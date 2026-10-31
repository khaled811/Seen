import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

enum PassportPhotoSource { camera, gallery }

class PassportPhoto extends Equatable {
  const PassportPhoto({required this.path, required this.fileName});

  final String path;
  final String fileName;

  @override
  List<Object?> get props => [path, fileName];
}

/// Takes or chooses a photo of the passport. `Right(null)` = the person backed out; `Left` carries
/// [cameraDeniedCode] / [photosDeniedCode] when the permission is refused for good.
abstract interface class PassportPhotoPicker {
  static const cameraDeniedCode = 'CAMERA_PERMISSION_DENIED';
  static const photosDeniedCode = 'PHOTOS_PERMISSION_DENIED';

  Future<Either<Failure, PassportPhoto?>> pick(PassportPhotoSource source);
}
