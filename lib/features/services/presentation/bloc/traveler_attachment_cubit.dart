// Per-traveler attachment (Figma BOOK-06). There is no booking-attachment upload API
// yet, so the file is only held on the device: the UI says it was not sent.
// TODO(backend-contract): upload on submit once the booking contract carries files.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../requests/domain/entities/missing_document.dart';
import '../../../requests/domain/services/document_picker.dart';

enum AttachmentError { tooLarge, wrongType, unavailable }

const attachmentAllowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
const attachmentMaxBytes = 5 * 1024 * 1024;

class TravelerAttachmentState extends Equatable {
  const TravelerAttachmentState({this.files = const {}, this.error, this.errorTravelerId});

  /// Keyed by traveler id.
  final Map<String, PickedDocument> files;
  final AttachmentError? error;
  final String? errorTravelerId;

  @override
  List<Object?> get props => [files, error, errorTravelerId];
}

class TravelerAttachmentCubit extends Cubit<TravelerAttachmentState> {
  /// [picker] is resolved lazily so nothing is created until a file is picked.
  TravelerAttachmentCubit(this._picker) : super(const TravelerAttachmentState());

  final DocumentPicker Function() _picker;
  bool _busy = false;

  Future<void> pick(String travelerId, DocumentSource source) async {
    if (_busy) return; // ignore double taps while the picker is open
    _busy = true;
    try {
      final result = await _picker().pick(source, allowedExtensions: attachmentAllowedExtensions);
      if (isClosed) return;
      result.fold(
        (_) => emit(TravelerAttachmentState(
            files: state.files, error: AttachmentError.unavailable, errorTravelerId: travelerId)),
        (doc) {
          if (doc == null) return; // cancelled
          final error = !attachmentAllowedExtensions.contains(doc.extension)
              ? AttachmentError.wrongType
              : (doc.sizeBytes > attachmentMaxBytes ? AttachmentError.tooLarge : null);
          if (error != null) {
            emit(TravelerAttachmentState(files: state.files, error: error, errorTravelerId: travelerId));
          } else {
            emit(TravelerAttachmentState(files: {...state.files, travelerId: doc}));
          }
        },
      );
    } finally {
      _busy = false;
    }
  }

  void remove(String travelerId) {
    emit(TravelerAttachmentState(files: {...state.files}..remove(travelerId)));
  }
}
