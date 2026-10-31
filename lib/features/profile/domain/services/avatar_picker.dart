import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/avatar.dart';

enum AvatarSource { camera, gallery }

/// Takes or chooses a photo. `Right(null)` = the person backed out; `Left` carries
/// `AvatarIssue.cameraDeniedCode` / `photosDeniedCode` when the permission is refused for good.
abstract interface class AvatarPicker {
  Future<Either<Failure, PickedAvatar?>> pick(AvatarSource source);
}
