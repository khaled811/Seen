import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/profile/domain/entities/avatar.dart';
import 'package:seen_booking/features/profile/domain/repositories/avatar_repository.dart';
import 'package:seen_booking/features/profile/domain/services/avatar_picker.dart';

/// A scripted [AvatarRepository]; set the answers, read the calls.
class FakeAvatarRepository implements AvatarRepository {
  Either<Failure, String?> currentResult = const Right(null);
  Either<Failure, String?> uploadResult = const Right('https://files.example/avatar.png');
  Either<Failure, void> removeResult = const Right(null);

  /// When set, `upload` waits for it (progress is reported first).
  Completer<void>? hold;
  List<double> progress = const [];

  int currentCalls = 0;
  final uploads = <Uint8List>[];
  int removeCalls = 0;

  @override
  Future<Either<Failure, String?>> currentUrl() async {
    currentCalls++;
    return currentResult;
  }

  @override
  Future<Either<Failure, String?>> upload(Uint8List bytes, {required String fileName, void Function(double fraction)? onProgress}) async {
    uploads.add(bytes);
    for (final p in progress) {
      onProgress?.call(p);
    }
    await hold?.future;
    return uploadResult;
  }

  @override
  Future<Either<Failure, void>> remove() async {
    removeCalls++;
    return removeResult;
  }
}

/// A scripted [AvatarPicker].
class FakeAvatarPicker implements AvatarPicker {
  Either<Failure, PickedAvatar?> result = const Right(PickedAvatar(path: 'p.jpg', fileName: 'p.jpg', sizeBytes: 1000));
  final sources = <AvatarSource>[];

  @override
  Future<Either<Failure, PickedAvatar?>> pick(AvatarSource source) async {
    sources.add(source);
    return result;
  }
}
