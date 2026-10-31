import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// A photo the person picked, before it is cropped and sent.
class PickedAvatar extends Equatable {
  const PickedAvatar({required this.path, required this.fileName, required this.sizeBytes});

  final String path;
  final String fileName;
  final int sizeBytes;

  /// What the profile photo may be (design/gaps PROF-02): JPG or PNG, up to 5 MB.
  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExtensions = ['jpg', 'jpeg', 'png'];

  bool get isAllowedType {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 && allowedExtensions.contains(fileName.substring(dot + 1).toLowerCase());
  }

  bool get isTooLarge => sizeBytes > maxBytes;

  @override
  List<Object?> get props => [path, fileName, sizeBytes];
}

enum AvatarIssueKind { tooLarge, wrongType, offline, generic, cameraDenied, photosDenied }

class AvatarIssue extends Equatable {
  const AvatarIssue(this.kind, {this.sizeBytes});

  final AvatarIssueKind kind;

  /// The size of the refused photo (`tooLarge`).
  final int? sizeBytes;

  /// Codes of the contract and of the picker.
  static const typeInvalidCode = 'avatar_type_invalid';
  static const fileTooLargeCode = 'file_too_large';
  static const cameraDeniedCode = 'CAMERA_PERMISSION_DENIED';
  static const photosDeniedCode = 'PHOTOS_PERMISSION_DENIED';

  factory AvatarIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const AvatarIssue(AvatarIssueKind.offline);
    }
    if (failure is ServerFailure) {
      return switch (failure.code) {
        typeInvalidCode || 'file_type_not_allowed' || 'file_content_mismatch' => const AvatarIssue(AvatarIssueKind.wrongType),
        fileTooLargeCode => const AvatarIssue(AvatarIssueKind.tooLarge),
        cameraDeniedCode => const AvatarIssue(AvatarIssueKind.cameraDenied),
        photosDeniedCode => const AvatarIssue(AvatarIssueKind.photosDenied),
        _ => const AvatarIssue(AvatarIssueKind.generic),
      };
    }
    return const AvatarIssue(AvatarIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, sizeBytes];
}
