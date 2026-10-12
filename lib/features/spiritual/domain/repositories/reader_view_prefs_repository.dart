import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/reader_view_prefs.dart';

abstract interface class ReaderViewPrefsRepository {
  Future<Either<Failure, ReaderViewPrefs>> load();
  Future<Either<Failure, ReaderViewPrefs>> save(ReaderViewPrefs prefs);
}
