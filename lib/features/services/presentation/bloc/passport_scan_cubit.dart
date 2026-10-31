// Reading a passport from a photo (design/gaps PASS-02..04): capture, reading, review. The reading
// is only a suggestion; the person chooses what goes into the traveler form.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/passport_reading.dart';
import '../../domain/repositories/passport_reader_repository.dart';
import '../../domain/services/passport_photo_picker.dart';

enum PassportStage { capture, reading, review, failed, unavailable }

/// One suggestion in the review, and whether it will be applied.
class PassportRow extends Equatable {
  const PassportRow({required this.suggestion, required this.selected});

  final PassportSuggestion suggestion;
  final bool selected;

  @override
  List<Object?> get props => [suggestion, selected];
}

class PassportScanState extends Equatable {
  const PassportScanState({
    this.stage = PassportStage.capture,
    this.rows = const [],
    this.issue,
    this.notImage = false,
    this.pickerDenied,
  });

  final PassportStage stage;
  final List<PassportRow> rows;
  final PassportIssue? issue;

  /// The chosen file was not a JPG or PNG: a note above the capture area.
  final bool notImage;

  /// Camera or photos refused for good: `camera` or `photos`.
  final String? pickerDenied;

  int get selectedCount => rows.where((r) => r.selected).length;

  PassportScanState copyWith({
    PassportStage? stage,
    List<PassportRow>? rows,
    PassportIssue? issue,
    bool clearIssue = false,
    bool? notImage,
    String? pickerDenied,
    bool clearDenied = false,
  }) =>
      PassportScanState(
        stage: stage ?? this.stage,
        rows: rows ?? this.rows,
        issue: clearIssue ? null : (issue ?? this.issue),
        notImage: notImage ?? this.notImage,
        pickerDenied: clearDenied ? null : (pickerDenied ?? this.pickerDenied),
      );

  @override
  List<Object?> get props => [stage, rows, issue, notImage, pickerDenied];
}

class PassportScanCubit extends Cubit<PassportScanState> {
  /// [fieldKeys] are the form's fields in the order the form shows them: a suggestion for any
  /// other key is dropped (there is nowhere to put it), and the rows follow this order.
  PassportScanCubit({required PassportReaderRepository reader, required PassportPhotoPicker picker, required List<String> fieldKeys})
      : _reader = reader,
        _picker = picker,
        _fieldKeys = fieldKeys,
        super(const PassportScanState());

  final PassportReaderRepository _reader;
  final PassportPhotoPicker _picker;
  final List<String> _fieldKeys;

  // A reading whose answer arrives after the person cancelled is dropped.
  int _ticket = 0;

  static const _allowed = ['jpg', 'jpeg', 'png'];

  Future<void> capture(PassportPhotoSource source) async {
    if (state.stage == PassportStage.reading) {
      return;
    }
    final picked = await _picker.pick(source);
    if (isClosed) {
      return;
    }
    final photo = picked.fold<PassportPhoto?>((failure) {
      final code = failure.toString();
      final denied = code.contains(PassportPhotoPicker.cameraDeniedCode)
          ? 'camera'
          : (code.contains(PassportPhotoPicker.photosDeniedCode) ? 'photos' : null);
      emit(state.copyWith(pickerDenied: denied, notImage: false, issue: const PassportIssue(PassportIssueKind.generic)));
      return null;
    }, (p) => p);
    if (photo == null) {
      return;
    }
    final dot = photo.fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : photo.fileName.substring(dot + 1).toLowerCase();
    if (!_allowed.contains(extension)) {
      emit(state.copyWith(notImage: true, clearDenied: true));
      return;
    }
    await _read(photo);
  }

  Future<void> _read(PassportPhoto photo) async {
    final ticket = ++_ticket;
    emit(state.copyWith(stage: PassportStage.reading, notImage: false, clearIssue: true, clearDenied: true));
    final result = await _reader.read(path: photo.path, fileName: photo.fileName);
    if (isClosed || ticket != _ticket) {
      return;
    }
    result.fold(
      (failure) {
        final issue = PassportIssue.from(failure);
        switch (issue.kind) {
          case PassportIssueKind.unavailable:
            emit(state.copyWith(stage: PassportStage.unavailable, issue: issue));
          case PassportIssueKind.notImage:
            emit(state.copyWith(stage: PassportStage.capture, notImage: true));
          default:
            emit(state.copyWith(stage: PassportStage.failed, issue: issue));
        }
      },
      (reading) {
        final byKey = {for (final s in reading.suggestions) s.key: s};
        final rows = [
          for (final key in _fieldKeys)
            if (byKey[key] != null) PassportRow(suggestion: byKey[key]!, selected: byKey[key]!.checked),
        ];
        if (rows.isEmpty) {
          emit(state.copyWith(stage: PassportStage.failed, issue: const PassportIssue(PassportIssueKind.unreadable)));
        } else {
          emit(state.copyWith(stage: PassportStage.review, rows: rows));
        }
      },
    );
  }

  /// Stops waiting for the reading; its answer, if it comes, is ignored.
  void cancel() {
    _ticket++;
    emit(state.copyWith(stage: PassportStage.capture, clearIssue: true));
  }

  /// Back to the capture step to take another photo.
  void retake() {
    _ticket++;
    emit(const PassportScanState());
  }

  void toggle(String key) {
    emit(state.copyWith(rows: [
      for (final r in state.rows) r.suggestion.key == key ? PassportRow(suggestion: r.suggestion, selected: !r.selected) : r,
    ]));
  }

  /// The chosen values, by field key: only what the person left selected.
  Map<String, String> get chosen => {
        for (final r in state.rows)
          if (r.selected) r.suggestion.key: r.suggestion.value,
      };
}
