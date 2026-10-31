import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// One place a document can be attached on a request: a traveler and one of the
/// service's document requirements (the upload endpoint needs both ids).
class UploadTarget extends Equatable {
  const UploadTarget({
    required this.travelerId,
    required this.requirementId,
    required this.requirementLabel,
    this.travelerLabel,
    this.alreadyUploaded = false,
  });

  final String travelerId;
  final String requirementId;
  final String requirementLabel;

  /// The traveler as the server shows them (the name may come masked).
  final String? travelerLabel;

  /// This traveler already has a file for this requirement.
  final bool alreadyUploaded;

  @override
  List<Object?> get props => [travelerId, requirementId, requirementLabel, travelerLabel, alreadyUploaded];
}

/// What a request in "info required" asks the agency for (Figma REQ-05): the
/// message and deadline come from the server, and the document goes to one of
/// [targets] (the server does not say which one it wants, so the first missing
/// one is preselected and the person can change it). Pure Dart.
class MissingDocumentRequest extends Equatable {
  const MissingDocumentRequest({
    required this.requestId,
    required this.referenceId,
    required this.reason,
    required this.targets,
    this.deadline,
    this.maxBytes = 8 * 1024 * 1024,
    this.allowedExtensions = const ['pdf', 'jpg', 'jpeg', 'png'],
  });

  final String requestId;
  final String referenceId;

  /// Why it is asked for, written by the authority (the server's `infoRequest.message`).
  final String reason;

  /// Where a file can go, the ones still missing first. Never empty.
  final List<UploadTarget> targets;

  /// Null when the server gives no deadline.
  final DateTime? deadline;
  final int maxBytes;

  /// Lower-case, without the dot.
  final List<String> allowedExtensions;

  bool get hasChoice => targets.length > 1;

  @override
  List<Object?> get props => [requestId, referenceId, reason, targets, deadline, maxBytes, allowedExtensions];
}

/// A file the user picked, not yet sent.
class PickedDocument extends Equatable {
  const PickedDocument({required this.path, required this.fileName, required this.sizeBytes});

  final String path;
  final String fileName;
  final int sizeBytes;

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  @override
  List<Object?> get props => [path, fileName, sizeBytes];
}

enum DocumentSource { file, gallery, camera }

/// What went wrong on the upload screens, in the vocabulary of Figma REQ-05b.
enum DocumentIssueKind {
  tooLarge,
  wrongType,
  offline,
  uploadFailed,
  deadlinePassed,
  pickerUnavailable,
  loadFailed,

  /// The camera / photo-library permission was refused for good (Figma SYS-07).
  cameraDenied,
  photosDenied,
}

class DocumentIssue extends Equatable {
  const DocumentIssue(this.kind);

  final DocumentIssueKind kind;

  /// The upload endpoint's error codes (contract 8.1). `document_upload_not_allowed`
  /// means the request no longer takes documents (it left "info required").
  static const notAllowedCode = 'document_upload_not_allowed';
  static const tooLargeCode = 'file_too_large';
  static const wrongTypeCodes = {'file_type_not_allowed', 'file_content_mismatch'};

  factory DocumentIssue.fromUpload(Failure failure) {
    if (failure is NetworkFailure) return const DocumentIssue(DocumentIssueKind.offline);
    if (failure is ServerFailure) {
      final code = failure.code;
      return DocumentIssue(
        code == notAllowedCode
            ? DocumentIssueKind.deadlinePassed
            : code == tooLargeCode
                ? DocumentIssueKind.tooLarge
                : wrongTypeCodes.contains(code)
                    ? DocumentIssueKind.wrongType
                    : DocumentIssueKind.uploadFailed,
      );
    }
    return const DocumentIssue(DocumentIssueKind.uploadFailed);
  }

  @override
  List<Object?> get props => [kind];
}
