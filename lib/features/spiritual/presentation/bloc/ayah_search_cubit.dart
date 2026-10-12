import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ayah_match.dart';
import '../../domain/usecases/quran_usecases.dart';

sealed class AyahSearchState extends Equatable {
  const AyahSearchState();

  @override
  List<Object?> get props => [];
}

class AyahSearchLoading extends AyahSearchState {
  const AyahSearchLoading();
}

class AyahSearchFailure extends AyahSearchState {
  const AyahSearchFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AyahSearchResults extends AyahSearchState {
  const AyahSearchResults(this.matches, {required this.capped});

  final List<AyahMatch> matches;

  /// More matches exist than are shown.
  final bool capped;

  @override
  List<Object?> get props => [matches, capped];
}

/// Full-text ayah search for one query.
class AyahSearchCubit extends Cubit<AyahSearchState> {
  AyahSearchCubit({
    required this.query,
    required LoadQuranUseCase loadQuran,
  })  : _loadQuran = loadQuran,
        super(const AyahSearchLoading());

  static const limit = 100;

  final String query;
  final LoadQuranUseCase _loadQuran;

  Future<void> search() async {
    final result = await _loadQuran();
    if (isClosed) return;
    // Let the loading frame paint before the (one-off) index build.
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    result.fold(
      (failure) => emit(AyahSearchFailure(failure.message)),
      (data) {
        final hits = data.search(query, limit: limit + 1);
        emit(AyahSearchResults(
          hits.take(limit).toList(growable: false),
          capped: hits.length > limit,
        ));
      },
    );
  }
}
