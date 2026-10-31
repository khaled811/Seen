import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/preferences/reveal_intro_store.dart';
import 'package:seen_booking/features/requests/domain/entities/sensitive_value.dart';
import 'package:seen_booking/features/requests/domain/repositories/sensitive_values_repository.dart';

const testSensitiveTravelers = [
  TravelerSensitive(travelerId: 't1', values: [
    SensitiveValue(id: 'v-passport', label: 'رقم الجواز', masked: '••••••4821'),
    SensitiveValue(id: 'v-phone', label: 'رقم الجوال', masked: '+966 5•• ••• 214'),
  ]),
  TravelerSensitive(travelerId: 't2', values: [
    SensitiveValue(id: 'v-passport-2', label: 'رقم الجواز', masked: '••••••9911'),
  ]),
];

/// A scripted [SensitiveValuesRepository]; set the answers, read the calls.
class FakeSensitiveValuesRepository implements SensitiveValuesRepository {
  Either<Failure, List<TravelerSensitive>> valuesResult = const Right(testSensitiveTravelers);
  final clearTexts = <String, Either<Failure, String>>{
    'v-passport': const Right('N08494821'),
    'v-phone': const Right('+966512345214'),
    'v-passport-2': const Right('N08499911'),
  };

  /// When set, `reveal` waits for it.
  Completer<void>? hold;

  final revealed = <String>[];

  @override
  Future<Either<Failure, List<TravelerSensitive>>> forRequest(String requestId) async => valuesResult;

  @override
  Future<Either<Failure, String>> reveal(String valueId) async {
    revealed.add(valueId);
    await hold?.future;
    return clearTexts[valueId] ?? const Left(ServerFailure('x', code: 'field_value_not_found'));
  }
}

/// An in-memory [RevealIntroStore].
class FakeRevealIntroStore implements RevealIntroStore {
  FakeRevealIntroStore({this.isSeen = false});

  bool isSeen;

  @override
  Future<bool> seen() async => isSeen;

  @override
  Future<void> markSeen() async => isSeen = true;
}
