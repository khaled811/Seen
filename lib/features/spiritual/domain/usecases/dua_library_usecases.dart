import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dua.dart';
import '../entities/dua_filter.dart';
import '../entities/dua_user_data.dart';
import '../repositories/dua_user_data_repository.dart';
import '../services/dua_sharer.dart';
import '../utils/dua_text.dart';

class LoadDuaUserDataUseCase {
  const LoadDuaUserDataUseCase(this._repository);

  final DuaUserDataRepository _repository;

  Future<Either<Failure, DuaUserData>> call() => _repository.load();
}

class ToggleFavoriteDuaUseCase {
  const ToggleFavoriteDuaUseCase(this._repository);

  final DuaUserDataRepository _repository;

  Future<Either<Failure, DuaUserData>> call(String id) =>
      _repository.toggleFavorite(id);
}

class SaveDuaFilterUseCase {
  const SaveDuaFilterUseCase(this._repository);

  final DuaUserDataRepository _repository;

  Future<Either<Failure, DuaUserData>> call(DuaFilter filter) =>
      _repository.saveFilter(filter);
}

class ShareDuaUseCase {
  const ShareDuaUseCase(this._sharer);

  final DuaSharer _sharer;

  Future<bool> call(Dua dua) =>
      _sharer.share(subject: dua.title, text: duaShareText(dua));
}

class CopyDuaUseCase {
  const CopyDuaUseCase(this._clipboard);

  final TextClipboard _clipboard;

  /// Returns false when the clipboard refused the text.
  Future<bool> call(Dua dua) async {
    try {
      await _clipboard.copy(duaShareText(dua));
      return true;
    } catch (_) {
      return false;
    }
  }
}
