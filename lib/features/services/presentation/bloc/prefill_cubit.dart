import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/prefill.dart';
import '../../domain/usecases/prefill_usecases.dart';

enum PrefillStatus {
  /// Reading the candidates; nothing is shown yet.
  loading,

  /// Earlier requests can be copied: the link is shown.
  available,

  /// Nothing to offer (the service has no rule, or the list could not be read): no link.
  none,

  /// Reading the values of the chosen request.
  using,
}

class PrefillState extends Equatable {
  const PrefillState({this.status = PrefillStatus.loading, this.candidates = const [], this.failure});

  final PrefillStatus status;
  final List<PrefillCandidate> candidates;

  /// Why the last "use this request" failed; the screen words it.
  final Failure? failure;

  @override
  List<Object?> get props => [status, candidates, failure];
}

/// Offers "copy the details of an earlier request" (the airline circular from its
/// approval, for example) for one service. Owner: the widget that shows the link.
class PrefillCubit extends Cubit<PrefillState> {
  PrefillCubit({
    required GetPrefillCandidatesUseCase candidates,
    required GetPrefillValuesUseCase values,
    required this.serviceId,
  })  : _candidates = candidates,
        _values = values,
        super(const PrefillState());

  final GetPrefillCandidatesUseCase _candidates;
  final GetPrefillValuesUseCase _values;
  final String serviceId;

  Future<void> load() async {
    final result = await _candidates(serviceId);
    if (isClosed) return;
    emit(result.fold(
      // An optional helper: when it cannot be read the form simply has no link.
      (_) => const PrefillState(status: PrefillStatus.none),
      (list) => list.isEmpty ? const PrefillState(status: PrefillStatus.none) : PrefillState(status: PrefillStatus.available, candidates: list),
    ));
  }

  /// Reads the values of [requestId]. One read at a time (the server audits each);
  /// null when it failed (then [PrefillState.failure] says why).
  Future<PrefillValues?> use(String requestId) async {
    if (state.status != PrefillStatus.available) return null;
    emit(PrefillState(status: PrefillStatus.using, candidates: state.candidates));
    final result = await _values(serviceId: serviceId, sourceRequestId: requestId);
    if (isClosed) return null;
    return result.fold(
      (f) {
        emit(PrefillState(status: PrefillStatus.available, candidates: state.candidates, failure: f));
        return null;
      },
      (values) {
        emit(PrefillState(status: PrefillStatus.available, candidates: state.candidates));
        return values;
      },
    );
  }
}
