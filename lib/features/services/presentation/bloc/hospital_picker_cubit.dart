import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/hospital.dart';
import '../../domain/repositories/hospital_repository.dart';

enum HospitalsStatus { loading, loaded, failure }

class HospitalPickerState extends Equatable {
  const HospitalPickerState({this.status = HospitalsStatus.loading, this.hospitals = const [], this.selectedId});

  final HospitalsStatus status;
  final List<Hospital> hospitals;
  final String? selectedId;

  Hospital? get selected => hospitals.where((h) => h.id == selectedId).firstOrNull;

  /// Every hospital is full this week: nothing can be chosen.
  bool get allFull => status == HospitalsStatus.loaded && hospitals.isNotEmpty && hospitals.every((h) => h.isFull);

  @override
  List<Object?> get props => [status, hospitals, selectedId];
}

/// The hospital picker of a medical service (Figma BOOK-10). The first hospital with places
/// left is pre-selected; a full one cannot be chosen.
class HospitalPickerCubit extends Cubit<HospitalPickerState> {
  HospitalPickerCubit(this._repository, {required this.serviceId}) : super(const HospitalPickerState());

  final HospitalRepository _repository;
  final String serviceId;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      emit(const HospitalPickerState());
      final r = await _repository.availability(serviceId);
      if (isClosed) {
        return;
      }
      r.fold(
        (_) => emit(const HospitalPickerState(status: HospitalsStatus.failure)),
        (list) => emit(HospitalPickerState(
          status: HospitalsStatus.loaded,
          hospitals: list,
          selectedId: list.where((h) => !h.isFull).firstOrNull?.id,
        )),
      );
    } finally {
      _loading = false;
    }
  }

  void select(String id) {
    final h = state.hospitals.where((x) => x.id == id).firstOrNull;
    if (h == null || h.isFull) {
      return;
    }
    emit(HospitalPickerState(status: state.status, hospitals: state.hospitals, selectedId: id));
  }
}
