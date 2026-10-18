// The airline circular form (Figma REQ-15b): travelers copied from the linked approval and
// locked, the ticket as the only document, the flight, send. One send at a time.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../requests/domain/entities/missing_document.dart';
import '../../../requests/domain/services/document_picker.dart';
import '../../domain/entities/airline_circular.dart';
import '../../domain/repositories/airline_circular_repository.dart';

enum CircularStage { choosing, loading, ready, failure }

enum TicketError {
  tooLarge,
  wrongType,
  unavailable,
  cameraDenied,
  photosDenied
}

enum CircularNotice { failed }

const ticketAllowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
const ticketMaxBytes = 5 * 1024 * 1024;

class AirlineCircularState extends Equatable {
  const AirlineCircularState({
    this.stage = CircularStage.choosing,
    this.prefill,
    this.ticket,
    this.ticketError,
    this.flightNumber = '',
    this.flightDate,
    this.showErrors = false,
    this.busy = false,
    this.submitted = false,
    this.notice,
    this.noticeSeq = 0,
  });

  final CircularStage stage;
  final CircularPrefill? prefill;
  final CircularTicket? ticket;
  final TicketError? ticketError;
  final String flightNumber;
  final DateTime? flightDate;

  /// Missing parts are only flagged after a first send attempt.
  final bool showErrors;
  final bool busy;
  final bool submitted;
  final CircularNotice? notice;
  final int noticeSeq;

  bool get flightNumberValid => normalizeFlightNumber(flightNumber) != null;

  AirlineCircularState copyWith({
    CircularStage? stage,
    CircularPrefill? prefill,
    CircularTicket? ticket,
    bool clearTicketError = false,
    TicketError? ticketError,
    String? flightNumber,
    DateTime? flightDate,
    bool? showErrors,
    bool? busy,
    bool? submitted,
    CircularNotice? notice,
  }) =>
      AirlineCircularState(
        stage: stage ?? this.stage,
        prefill: prefill ?? this.prefill,
        ticket: ticket ?? this.ticket,
        ticketError:
            clearTicketError ? null : (ticketError ?? this.ticketError),
        flightNumber: flightNumber ?? this.flightNumber,
        flightDate: flightDate ?? this.flightDate,
        showErrors: showErrors ?? this.showErrors,
        busy: busy ?? this.busy,
        submitted: submitted ?? this.submitted,
        notice: notice ?? this.notice,
        noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
      );

  @override
  List<Object?> get props => [
        stage,
        prefill,
        ticket,
        ticketError,
        flightNumber,
        flightDate,
        showErrors,
        busy,
        submitted,
        notice,
        noticeSeq
      ];
}

class AirlineCircularCubit extends Cubit<AirlineCircularState> {
  /// [picker] is resolved lazily so nothing is created until a file is picked. [now] is a test seam.
  AirlineCircularCubit(this._repository, this._picker,
      {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const AirlineCircularState());

  final AirlineCircularRepository _repository;
  final DocumentPicker Function() _picker;
  final DateTime Function() _now;
  bool _picking = false;

  /// The newest answer wins: a slower earlier prefill never overwrites a later choice.
  int _prefillSeq = 0;

  /// Links the circular to [approvalId]: its travelers are copied in and locked. The flight
  /// and the ticket already entered are kept when the approval is changed.
  Future<void> link(String approvalId) async {
    final seq = ++_prefillSeq;
    emit(state.copyWith(stage: CircularStage.loading));
    final r = await _repository.prefill(approvalId);
    if (isClosed || seq != _prefillSeq) return;
    r.fold(
      (_) => emit(state.copyWith(stage: CircularStage.failure)),
      (p) => emit(state.copyWith(stage: CircularStage.ready, prefill: p)),
    );
  }

  void setFlightNumber(String v) => emit(state.copyWith(flightNumber: v));

  void setFlightDate(DateTime d) =>
      emit(state.copyWith(flightDate: DateTime(d.year, d.month, d.day)));

  Future<void> pickTicket(DocumentSource source) async {
    if (_picking) return; // ignore double taps while the picker is open
    _picking = true;
    try {
      final result = await _picker()
          .pick(source, allowedExtensions: ticketAllowedExtensions);
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(
          ticketError: switch (failure is ServerFailure ? failure.code : null) {
            cameraDeniedCode => TicketError.cameraDenied,
            photosDeniedCode => TicketError.photosDenied,
            _ => TicketError.unavailable,
          },
        )),
        (doc) {
          if (doc == null) return; // cancelled
          if (!ticketAllowedExtensions.contains(doc.extension)) {
            emit(state.copyWith(ticketError: TicketError.wrongType));
          } else if (doc.sizeBytes > ticketMaxBytes) {
            emit(state.copyWith(ticketError: TicketError.tooLarge));
          } else {
            emit(state.copyWith(
              clearTicketError: true,
              ticket: CircularTicket(
                  path: doc.path,
                  fileName: doc.fileName,
                  sizeBytes: doc.sizeBytes),
            ));
          }
        },
      );
    } finally {
      _picking = false;
    }
  }

  /// A circular is for a flight to come: today or later.
  bool dateOk(DateTime? d) {
    final n = _now();
    return d != null && !d.isBefore(DateTime(n.year, n.month, n.day));
  }

  bool get isComplete =>
      state.ticket != null &&
      state.flightNumberValid &&
      dateOk(state.flightDate);

  Future<void> submit() async {
    if (state.stage != CircularStage.ready ||
        state.busy ||
        state.prefill == null) return;
    if (!isComplete) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(state.copyWith(busy: true, showErrors: true));
    final r = await _repository.submit(CircularSubmission(
      approvalId: state.prefill!.approval.id,
      ticket: state.ticket!,
      flightNumber: normalizeFlightNumber(state.flightNumber)!,
      flightDate: state.flightDate!,
    ));
    if (isClosed) return;
    r.fold(
      (_) => emit(state.copyWith(busy: false, notice: CircularNotice.failed)),
      (_) => emit(state.copyWith(busy: false, submitted: true)),
    );
  }
}
