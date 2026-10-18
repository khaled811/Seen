import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/repositories/legal_repository.dart';

class GetLegalDocumentUseCase {
  const GetLegalDocumentUseCase(this._repository);

  final LegalRepository _repository;

  Future<LegalOutcome> call(LegalKind kind, LegalLanguage language) async {
    final r = await _repository.get(kind, language);
    return r.fold(LegalOutcome.failed, LegalOutcome.ok);
  }
}

/// A use-case answer without the Either, so the cubit stays small.
class LegalOutcome {
  const LegalOutcome._(this.result, this.failure);

  factory LegalOutcome.ok(LegalResult r) => LegalOutcome._(r, null);
  factory LegalOutcome.failed(Failure f) => LegalOutcome._(null, f);

  final LegalResult? result;
  final Failure? failure;
}

enum LegalStatus { loading, loaded, failure }

class LegalState extends Equatable {
  const LegalState({required this.language, this.status = LegalStatus.loading, this.result, this.failure});

  final LegalLanguage language;
  final LegalStatus status;
  final LegalResult? result;
  final Failure? failure;

  @override
  List<Object?> get props => [language, status, result, failure];
}

/// One legal text (Figma AUTH-09 terms, AUTH-10 privacy). Switching language reloads;
/// when two loads overlap, only the latest one is shown.
class LegalCubit extends Cubit<LegalState> {
  LegalCubit({required this.kind, required LegalLanguage initial, required GetLegalDocumentUseCase get})
      : _get = get,
        super(LegalState(language: initial));

  final LegalKind kind;
  final GetLegalDocumentUseCase _get;
  int _request = 0;

  Future<void> load() => _loadFor(state.language);

  Future<void> setLanguage(LegalLanguage language) async {
    if (language == state.language && state.status != LegalStatus.failure) {
      return;
    }
    await _loadFor(language);
  }

  Future<void> _loadFor(LegalLanguage language) async {
    final mine = ++_request;
    emit(LegalState(language: language));
    final outcome = await _get(kind, language);
    if (isClosed || mine != _request) {
      return; // a newer choice is already loading
    }
    final result = outcome.result;
    emit(result != null
        ? LegalState(language: language, status: LegalStatus.loaded, result: result)
        : LegalState(language: language, status: LegalStatus.failure, failure: outcome.failure));
  }
}
