import 'package:equatable/equatable.dart';

import '../../../requests/domain/entities/missing_document.dart';

/// What the server accepts for a traveler document (contract 8.1).
const bookingDocumentMaxBytes = 8 * 1024 * 1024;
const bookingDocumentExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// One file to attach to one traveler for one document requirement.
class BookingDocumentUpload extends Equatable {
  const BookingDocumentUpload({
    required this.requestId,
    required this.travelerId,
    required this.requirementId,
    required this.document,
  });

  final String requestId;
  final String travelerId;
  final String requirementId;
  final PickedDocument document;

  @override
  List<Object?> get props => [requestId, travelerId, requirementId, document];
}
