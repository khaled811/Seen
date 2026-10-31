import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/repositories/manifest_repository.dart';

/// Group manifests have no operations in the API (contract section 14): nothing
/// opens a manifest, adds or imports travelers into one, submits it or reads its
/// summary, so every call is `unsupported_operation`. Nothing is sent and nothing
/// is faked (DECISIONS P-06). More than nine travelers cannot be filed from the app.
class ManifestRemoteDataSource implements ManifestRepository {
  const ManifestRemoteDataSource();

  @override
  Future<Either<Failure, ManifestDraft>> openDraft({required String serviceId, required String serviceLabel}) async =>
      unsupportedOperation('Opening a group manifest');

  @override
  Future<Either<Failure, ManifestDraft>> addTraveler({
    required String draftId,
    required String name,
    String? passportNumber,
  }) async =>
      unsupportedOperation('Adding a manifest traveler');

  @override
  Future<Either<Failure, ManifestDraft>> importList({required String draftId, required ManifestImportFile file}) async =>
      unsupportedOperation('Importing a traveler list');

  @override
  Future<Either<Failure, void>> saveDraft(String draftId) async => unsupportedOperation('Saving a manifest draft');

  @override
  Future<Either<Failure, String>> submit(String draftId) async => unsupportedOperation('Submitting a manifest');

  @override
  Future<Either<Failure, ManifestSummary>> summary(String manifestId) async => unsupportedOperation('A manifest summary');

  @override
  Future<Either<Failure, ManifestSummary>> resubmit({required String manifestId, required String travelerId}) async =>
      unsupportedOperation('Resubmitting a manifest traveler');

  @override
  Future<Either<Failure, String>> issuedVisasUrl(String manifestId) async =>
      unsupportedOperation('Downloading a manifest\'s issued visas');
}

/// Picks a CSV / Excel file with the system picker and reads it. A file over
/// [manifestImportMaxBytes] is refused before it is read.
class PluginManifestImportPicker implements ManifestImportPicker {
  @override
  Future<Either<Failure, ManifestImportFile?>> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls'],
        withData: false,
      );
      final file = result?.files.single;
      if (file == null || file.path == null) return const Right(null);
      if (file.size > manifestImportMaxBytes) {
        return const Left(ServerFailure('Manifest import file is too large.',
            code: manifestImportTooLargeCode));
      }
      return Right(ManifestImportFile(
          name: file.name, bytes: await File(file.path!).readAsBytes()));
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'PICKER_UNAVAILABLE'));
    }
  }
}

/// DEBUG ONLY: when a real call fails in a debug build, answers from an in-memory copy of the
/// Figma sample (10 travelers, then the same manifest sent) so the screens can be used
/// without a backend. Release builds drop every branch (`kDebugMode` is a compile-time
/// constant). Nothing is persisted.
class DebugFallbackManifestRepository implements ManifestRepository {
  DebugFallbackManifestRepository(this._real);

  final ManifestRepository _real;

  static const _names = [
    'محمد عبدالله الحميري',
    'رقية أحمد الحميري',
    'سالم محمد الحميري',
    'فاطمة سالم الحميري',
    'عبدالله محمد الحميري',
    'خالد صالح الحميري',
    'مريم علي الحميري',
    'يوسف سالم الحميري',
    'هدى محمد الحميري',
    'أحمد خالد الحميري',
  ];

  late List<ManifestTraveler> _travelers = [
    for (var i = 0; i < _names.length; i++)
      switch (i) {
        2 => ManifestTraveler(
            id: 'm$i',
            name: _names[i],
            passportNumber: '09111584',
            problem: ManifestProblem.missingPassport),
        3 => ManifestTraveler(
            id: 'm$i',
            name: _names[i],
            problem: ManifestProblem.passportExpiring,
            monthsLeft: 4),
        _ => ManifestTraveler(
            id: 'm$i', name: _names[i], passportNumber: '0845${2197 + i * 6}'),
      },
  ];
  String _label = '';
  late List<ManifestTravelerStatus> _statuses = [
    for (var i = 0; i < _names.length; i++)
      ManifestTravelerStatus(
        id: 'm$i',
        name: _names[i],
        outcome: i < 6
            ? ManifestOutcome.issued
            : (i == 6 ? ManifestOutcome.rejected : ManifestOutcome.atAuthority),
        doneSteps: i < 6 ? 5 : (i == 6 ? 2 : 3),
        rejectionReason: i == 6 ? 'صلاحية الجواز أقل من ٦ أشهر' : null,
      ),
  ];

  bool get _debug => debugFallbacksEnabled;

  ManifestDraft get _draft0 => ManifestDraft(
      id: 'debug-manifest',
      serviceLabel: _label,
      travelers: List.of(_travelers));

  ManifestSummary get _summary0 => ManifestSummary(
      id: 'debug-manifest',
      reference: 'GM-0412',
      title: 'كشف عمرة · مكتب الريان',
      travelers: List.of(_statuses));

  @override
  Future<Either<Failure, ManifestDraft>> openDraft(
      {required String serviceId, required String serviceLabel}) async {
    final r =
        await _real.openDraft(serviceId: serviceId, serviceLabel: serviceLabel);
    if (_debug && r.isLeft()) {
      _label = serviceLabel;
      return Right(_draft0);
    }
    return r;
  }

  @override
  Future<Either<Failure, ManifestDraft>> addTraveler({
    required String draftId,
    required String name,
    String? passportNumber,
  }) async {
    final r = await _real.addTraveler(
        draftId: draftId, name: name, passportNumber: passportNumber);
    if (_debug && r.isLeft()) {
      final hasPassport = passportNumber != null && passportNumber.isNotEmpty;
      _travelers = [
        ..._travelers,
        ManifestTraveler(
          id: 'm${_travelers.length}',
          name: name,
          passportNumber: hasPassport ? passportNumber : null,
          problem: hasPassport
              ? ManifestProblem.none
              : ManifestProblem.missingPassport,
        ),
      ];
      return Right(_draft0);
    }
    return r;
  }

  @override
  Future<Either<Failure, ManifestDraft>> importList(
      {required String draftId, required ManifestImportFile file}) async {
    final r = await _real.importList(draftId: draftId, file: file);
    if (_debug && r.isLeft()) {
      _travelers = [
        ..._travelers,
        for (var i = 0; i < 3; i++)
          ManifestTraveler(
              id: 'i${_travelers.length + i}',
              name: 'مسافر مستورد ${_travelers.length + i + 1}',
              passportNumber: '0${7000000 + i}'),
      ];
      return Right(_draft0);
    }
    return r;
  }

  @override
  Future<Either<Failure, void>> saveDraft(String draftId) async {
    final r = await _real.saveDraft(draftId);
    return _debug && r.isLeft() ? const Right(null) : r;
  }

  @override
  Future<Either<Failure, String>> submit(String draftId) async {
    final r = await _real.submit(draftId);
    return _debug && r.isLeft() ? const Right('debug-manifest') : r;
  }

  @override
  Future<Either<Failure, ManifestSummary>> summary(String manifestId) async {
    final r = await _real.summary(manifestId);
    return _debug && r.isLeft() ? Right(_summary0) : r;
  }

  @override
  Future<Either<Failure, ManifestSummary>> resubmit(
      {required String manifestId, required String travelerId}) async {
    final r =
        await _real.resubmit(manifestId: manifestId, travelerId: travelerId);
    if (_debug && r.isLeft()) {
      _statuses = [
        for (final t in _statuses)
          t.id == travelerId
              ? ManifestTravelerStatus(
                  id: t.id,
                  name: t.name,
                  outcome: ManifestOutcome.atAuthority,
                  doneSteps: 2)
              : t,
      ];
      return Right(_summary0);
    }
    return r;
  }

  @override
  Future<Either<Failure, String>> issuedVisasUrl(String manifestId) async {
    final r = await _real.issuedVisasUrl(manifestId);
    return _debug && r.isLeft()
        ? const Right('https://example.invalid/issued-visas.zip')
        : r;
  }
}
