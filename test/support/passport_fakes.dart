import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/services/domain/entities/passport_reading.dart';
import 'package:seen_booking/features/services/domain/repositories/passport_reader_repository.dart';
import 'package:seen_booking/features/services/domain/services/passport_photo_picker.dart';

const testPassportSuggestions = [
  PassportSuggestion(key: 'passportNumber', value: 'N0849482', checked: true),
  PassportSuggestion(key: 'fullName', value: 'AMAL SALEH', checked: true),
  PassportSuggestion(key: 'nationality', value: 'YEM', checked: false),
  PassportSuggestion(key: 'notInTheForm', value: 'x', checked: true),
];

/// A scripted [PassportReaderRepository]; set the answer, read the calls.
class FakePassportReader implements PassportReaderRepository {
  Either<Failure, PassportReading> result = const Right(PassportReading(suggestions: testPassportSuggestions, allChecksPass: true));

  /// When set, `read` waits for it (to see the "reading" state or to cancel).
  Completer<void>? hold;

  final reads = <String>[];

  @override
  Future<Either<Failure, PassportReading>> read({required String path, required String fileName}) async {
    reads.add(path);
    await hold?.future;
    return result;
  }
}

/// A scripted [PassportPhotoPicker].
class FakePassportPicker implements PassportPhotoPicker {
  Either<Failure, PassportPhoto?> result = const Right(PassportPhoto(path: '/tmp/passport.jpg', fileName: 'passport.jpg'));
  final sources = <PassportPhotoSource>[];

  @override
  Future<Either<Failure, PassportPhoto?>> pick(PassportPhotoSource source) async {
    sources.add(source);
    return result;
  }
}
