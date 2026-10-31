import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// The signed-in user's profile photo (`me.avatarUrl`, `setMyAvatar`, `removeMyAvatar`).
abstract interface class AvatarRepository {
  /// The photo's address, or null when there is none. The link is short-lived: it is read again
  /// rather than kept.
  Future<Either<Failure, String?>> currentUrl();

  /// Sends the cropped photo ([bytes], PNG or JPEG) and makes it the profile photo; returns the
  /// new address. [onProgress] reports the share sent so far (0..1).
  Future<Either<Failure, String?>> upload(Uint8List bytes, {required String fileName, void Function(double fraction)? onProgress});

  Future<Either<Failure, void>> remove();
}
