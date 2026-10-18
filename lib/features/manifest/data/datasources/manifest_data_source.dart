import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/repositories/manifest_repository.dart';

ManifestDraft _draft(Map<String, dynamic> j) => ManifestDraft(
      id: j['id'] as String,
      serviceLabel: j['serviceLabel'] as String? ?? '',
      travelers: [
        for (final t in (j['travelers'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
          ManifestTraveler(
            id: t['id'] as String,
            name: t['name'] as String? ?? '',
            passportNumber: t['passportNumber'] as String?,
            problem: switch (t['problem'] as String?) {
              'MISSING_PASSPORT' => ManifestProblem.missingPassport,
              'PASSPORT_EXPIRING' => ManifestProblem.passportExpiring,
              _ => ManifestProblem.none,
            },
            monthsLeft: (t['monthsLeft'] as num?)?.toInt(),
          ),
      ],
    );

ManifestSummary _summary(Map<String, dynamic> j) => ManifestSummary(
      id: j['id'] as String,
      reference: j['reference'] as String? ?? '',
      title: j['title'] as String? ?? '',
      travelers: [
        for (final t in (j['travelers'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
          ManifestTravelerStatus(
            id: t['id'] as String,
            name: t['name'] as String? ?? '',
            outcome: switch (t['outcome'] as String?) {
              'ISSUED' => ManifestOutcome.issued,
              'REJECTED' => ManifestOutcome.rejected,
              _ => ManifestOutcome.atAuthority,
            },
            doneSteps: ((t['doneSteps'] as num?)?.toInt() ?? 0)
                .clamp(0, ManifestTravelerStatus.totalSteps),
            rejectionReason: t['rejectionReason'] as String?,
          ),
      ],
    );

/// GraphQL access to group manifests.
///
/// TODO(backend-contract): placeholder schema (`openManifest`, `addManifestTraveler`,
/// `importManifestList`, `saveManifestDraft`, `submitManifest`, `manifestSummary`,
/// `resubmitManifestTraveler`, `manifestIssuedVisasUrl`); see docs/BACKEND_MIGRATION_GAPS.md
/// section 45.
class ManifestRemoteDataSource implements ManifestRepository {
  ManifestRemoteDataSource({required GraphQLService graphQLService})
      : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static const _draftFields =
      'id serviceLabel travelers { id name passportNumber problem monthsLeft }';
  static const _summaryFields =
      'id reference title travelers { id name outcome doneSteps rejectionReason }';

  static final _openDoc = gql('''
    mutation OpenManifest(\$serviceId: ID!) { openManifest(serviceId: \$serviceId) { $_draftFields } }
  ''');
  static final _addDoc = gql('''
    mutation AddManifestTraveler(\$draftId: ID!, \$name: String!, \$passportNumber: String) {
      addManifestTraveler(draftId: \$draftId, name: \$name, passportNumber: \$passportNumber) { $_draftFields }
    }
  ''');
  static final _importDoc = gql('''
    mutation ImportManifestList(\$draftId: ID!, \$fileName: String!, \$contentBase64: String!) {
      importManifestList(draftId: \$draftId, fileName: \$fileName, contentBase64: \$contentBase64) { $_draftFields }
    }
  ''');
  static final _saveDoc = gql(r'''
    mutation SaveManifestDraft($draftId: ID!) { saveManifestDraft(draftId: $draftId) { success } }
  ''');
  static final _submitDoc = gql(r'''
    mutation SubmitManifest($draftId: ID!) { submitManifest(draftId: $draftId) { id } }
  ''');
  static final _summaryDoc = gql('''
    query ManifestSummary(\$id: ID!) { manifestSummary(id: \$id) { $_summaryFields } }
  ''');
  static final _resubmitDoc = gql('''
    mutation ResubmitManifestTraveler(\$manifestId: ID!, \$travelerId: ID!) {
      resubmitManifestTraveler(manifestId: \$manifestId, travelerId: \$travelerId) { $_summaryFields }
    }
  ''');
  static final _urlDoc = gql(r'''
    query ManifestIssuedVisasUrl($id: ID!) { manifestIssuedVisasUrl(id: $id) { url } }
  ''');

  @override
  Future<Either<Failure, ManifestDraft>> openDraft(
          {required String serviceId, required String serviceLabel}) =>
      _graphQL.mutate<ManifestDraft>(MutationOptions<ManifestDraft>(
        document: _openDoc,
        variables: {'serviceId': serviceId},
        parserFn: (j) => _draft(j['openManifest'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, ManifestDraft>> addTraveler({
    required String draftId,
    required String name,
    String? passportNumber,
  }) =>
      _graphQL.mutate<ManifestDraft>(MutationOptions<ManifestDraft>(
        document: _addDoc,
        variables: {
          'draftId': draftId,
          'name': name,
          'passportNumber': passportNumber
        },
        parserFn: (j) =>
            _draft(j['addManifestTraveler'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, ManifestDraft>> importList(
          {required String draftId, required ManifestImportFile file}) =>
      _graphQL.mutate<ManifestDraft>(MutationOptions<ManifestDraft>(
        document: _importDoc,
        variables: {
          'draftId': draftId,
          'fileName': file.name,
          'contentBase64': base64Encode(file.bytes)
        },
        parserFn: (j) =>
            _draft(j['importManifestList'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, void>> saveDraft(String draftId) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _saveDoc,
        variables: {'draftId': draftId},
        parserFn: (j) =>
            (j['saveManifestDraft'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      )))
          .map((_) {});

  @override
  Future<Either<Failure, String>> submit(String draftId) =>
      _graphQL.mutate<String>(MutationOptions<String>(
        document: _submitDoc,
        variables: {'draftId': draftId},
        parserFn: (j) =>
            (j['submitManifest'] as Map<String, dynamic>)['id'] as String,
      ));

  @override
  Future<Either<Failure, ManifestSummary>> summary(String manifestId) =>
      _graphQL.query<ManifestSummary>(QueryOptions<ManifestSummary>(
        document: _summaryDoc,
        variables: {'id': manifestId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => _summary(j['manifestSummary'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, ManifestSummary>> resubmit(
          {required String manifestId, required String travelerId}) =>
      _graphQL.mutate<ManifestSummary>(MutationOptions<ManifestSummary>(
        document: _resubmitDoc,
        variables: {'manifestId': manifestId, 'travelerId': travelerId},
        parserFn: (j) =>
            _summary(j['resubmitManifestTraveler'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, String>> issuedVisasUrl(String manifestId) =>
      _graphQL.query<String>(QueryOptions<String>(
        document: _urlDoc,
        variables: {'id': manifestId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => (j['manifestIssuedVisasUrl']
            as Map<String, dynamic>)['url'] as String,
      ));
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

  bool get _debug => kDebugMode;

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
