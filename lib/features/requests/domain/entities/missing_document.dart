import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// A document the reviewing authority asked for on a request that is in
/// "info required" (Figma REQ-05). Pure Dart.
class MissingDocumentRequest extends Equatable {
  const MissingDocumentRequest({
    required this.requestId,
    required this.referenceId,
    required this.documentTitle,
    required this.reason,
    required this.deadline,
    this.travelerName,
    this.maxBytes = 5 * 1024 * 1024,
    this.allowedExtensions = const ['jpg', 'jpeg', 'png', 'pdf'],
  });

  final String requestId;
  final String referenceId;

  /// What is asked for, e.g. "A clear passport photo".
  final String documentTitle;
  final String? travelerName;

  /// Why it is asked for, written by the authority.
  final String reason;
  final DateTime deadline;
  final int maxBytes;

  /// Lower-case, without the dot.
  final List<String> allowedExtensions;

  @override
  List<Object?> get props =>
      [requestId, referenceId, documentTitle, travelerName, reason, deadline, maxBytes, allowedExtensions];
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

  /// Backend error codes (GraphQL `extensions.code`) this mapping expects.
  /// TODO(backend-contract): confirm the names; see docs/BACKEND_MIGRATION_GAPS.md.
  static const deadlinePassedCode = 'DEADLINE_PASSED';
  static const tooLargeCode = 'FILE_TOO_LARGE';
  static const wrongTypeCode = 'FILE_TYPE_NOT_ALLOWED';

  factory DocumentIssue.fromUpload(Failure failure) {
    if (failure is NetworkFailure) return const DocumentIssue(DocumentIssueKind.offline);
    if (failure is ServerFailure) {
      return DocumentIssue(switch (failure.code) {
        deadlinePassedCode => DocumentIssueKind.deadlinePassed,
        tooLargeCode => DocumentIssueKind.tooLarge,
        wrongTypeCode => DocumentIssueKind.wrongType,
        _ => DocumentIssueKind.uploadFailed,
      });
    }
    return const DocumentIssue(DocumentIssueKind.uploadFailed);
  }

  @override
  List<Object?> get props => [kind];
}
