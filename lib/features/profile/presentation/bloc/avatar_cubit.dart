// The signed-in user's profile photo (design/gaps PROF-01..03), shared by the screens that show
// it. It holds the photo's address only for the session: the app clears it when the session ends.
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/avatar.dart';
import '../../domain/repositories/avatar_repository.dart';

enum AvatarEvent { updated, deleted }

class AvatarState extends Equatable {
  const AvatarState({this.url, this.loaded = false, this.progress, this.fileName, this.sizeBytes, this.issue, this.event});

  /// The photo's address; null = none (the initial or glyph shows).
  final String? url;

  /// The address was read from the server at least once this session.
  final bool loaded;

  /// 0..1 while a photo is being sent, else null.
  final double? progress;
  final String? fileName;
  final int? sizeBytes;
  final AvatarIssue? issue;

  /// A result to tell the person about (a toast); the screen clears it with `eventShown`.
  final AvatarEvent? event;

  bool get uploading => progress != null;

  AvatarState copyWith({
    String? url,
    bool clearUrl = false,
    bool? loaded,
    double? progress,
    bool clearProgress = false,
    String? fileName,
    int? sizeBytes,
    AvatarIssue? issue,
    bool clearIssue = false,
    AvatarEvent? event,
    bool clearEvent = false,
  }) =>
      AvatarState(
        url: clearUrl ? null : (url ?? this.url),
        loaded: loaded ?? this.loaded,
        progress: clearProgress ? null : (progress ?? this.progress),
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        issue: clearIssue ? null : (issue ?? this.issue),
        event: clearEvent ? null : (event ?? this.event),
      );

  @override
  List<Object?> get props => [url, loaded, progress, fileName, sizeBytes, issue, event];
}

class AvatarCubit extends Cubit<AvatarState> {
  AvatarCubit(this._repository) : super(const AvatarState());

  final AvatarRepository _repository;
  bool _loading = false;

  // The last cropped photo, kept in memory only so "retry" can send it again.
  Uint8List? _pending;
  String _pendingName = 'profile.png';

  /// Reads the photo's address once per session (and again after [clear]).
  Future<void> load() async {
    if (state.loaded || _loading) {
      return;
    }
    _loading = true;
    final result = await _repository.currentUrl();
    _loading = false;
    if (isClosed) {
      return;
    }
    result.fold(
      // Not loaded: the next screen tries again; the glyph stays meanwhile.
      (_) {},
      (url) => emit(state.copyWith(url: url, clearUrl: url == null, loaded: true)),
    );
  }

  /// The picked photo is refused before it is cropped (too large or not JPG/PNG).
  void reject(PickedAvatar picked) {
    if (picked.isTooLarge) {
      emit(state.copyWith(issue: AvatarIssue(AvatarIssueKind.tooLarge, sizeBytes: picked.sizeBytes)));
    } else if (!picked.isAllowedType) {
      emit(state.copyWith(issue: const AvatarIssue(AvatarIssueKind.wrongType)));
    }
  }

  void report(AvatarIssue issue) => emit(state.copyWith(issue: issue));

  /// Sends the cropped photo. A second call while one is running is ignored.
  Future<void> upload(Uint8List bytes, {String fileName = 'profile.png'}) async {
    if (state.uploading) {
      return;
    }
    _pending = bytes;
    _pendingName = fileName;
    await _send();
  }

  /// "Retry" after a failed upload.
  Future<void> retry() async {
    final bytes = _pending;
    if (bytes == null || state.uploading) {
      return;
    }
    await _send();
  }

  Future<void> _send() async {
    final bytes = _pending!;
    emit(state.copyWith(progress: 0, fileName: _pendingName, sizeBytes: bytes.length, clearIssue: true));
    final result = await _repository.upload(
      bytes,
      fileName: _pendingName,
      onProgress: (fraction) {
        if (!isClosed && state.uploading) {
          emit(state.copyWith(progress: fraction.clamp(0.0, 1.0)));
        }
      },
    );
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(state.copyWith(clearProgress: true, issue: AvatarIssue.from(f))),
      (url) {
        _pending = null;
        emit(state.copyWith(url: url, clearUrl: url == null, loaded: true, clearProgress: true, event: AvatarEvent.updated));
      },
    );
  }

  Future<void> remove() async {
    if (state.uploading) {
      return;
    }
    final result = await _repository.remove();
    if (isClosed) {
      return;
    }
    result.fold(
      (f) => emit(state.copyWith(issue: AvatarIssue.from(f))),
      (_) => emit(state.copyWith(clearUrl: true, loaded: true, event: AvatarEvent.deleted, clearIssue: true)),
    );
  }

  void dismissIssue() {
    if (state.issue != null) {
      emit(state.copyWith(clearIssue: true));
    }
  }

  void eventShown() {
    if (state.event != null) {
      emit(state.copyWith(clearEvent: true));
    }
  }

  /// The session ended: the next person must not see this photo.
  void clear() {
    _pending = null;
    emit(const AvatarState());
  }
}
