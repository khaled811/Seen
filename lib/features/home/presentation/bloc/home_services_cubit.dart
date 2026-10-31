import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/home_service.dart';
import '../../domain/repositories/home_repository.dart';

class HomeServicesState extends Equatable {
  const HomeServicesState({this.services = const [], this.failure});

  final List<HomeService> services;

  /// Why the last read failed. The shortcuts are a convenience (the full catalog is one tap
  /// away), so the screen shows none and keeps the ones already shown after a failed refresh.
  final Failure? failure;

  @override
  List<Object?> get props => [services, failure];
}

/// The service shortcuts of the home screen. Owner: the home screen.
class HomeServicesCubit extends Cubit<HomeServicesState> {
  HomeServicesCubit(this._repository) : super(const HomeServicesState());

  final HomeRepository _repository;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _repository.services();
      if (isClosed) return;
      result.fold(
        (f) => emit(HomeServicesState(services: state.services, failure: f)),
        (list) => emit(HomeServicesState(services: list)),
      );
    } finally {
      _loading = false;
    }
  }
}
