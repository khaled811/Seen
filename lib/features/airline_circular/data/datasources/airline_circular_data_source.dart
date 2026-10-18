import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/airline_circular.dart';
import '../../domain/repositories/airline_circular_repository.dart';

ApprovedSecurityRequest _approval(Map<String, dynamic> j) =>
    ApprovedSecurityRequest(
      id: j['id'] as String,
      reference: j['reference'] as String? ?? '',
      leadName: j['leadName'] as String? ?? '',
      travelerCount: (j['travelerCount'] as num?)?.toInt() ?? 0,
      issuedAt: DateTime.tryParse(j['issuedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );

/// GraphQL access to airline circulars.
///
/// TODO(backend-contract): placeholder schema (`approvedSecurityRequests`,
/// `circularPrefill`, `submitAirlineCircular`); see docs/BACKEND_MIGRATION_GAPS.md section 46.
class AirlineCircularRemoteDataSource implements AirlineCircularRepository {
  AirlineCircularRemoteDataSource({required GraphQLService graphQLService})
      : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static const _approvalFields = 'id reference leadName travelerCount issuedAt';

  static final _listDoc = gql(
      'query ApprovedSecurityRequests { approvedSecurityRequests { $_approvalFields } }');

  static final _prefillDoc = gql('''
    query CircularPrefill(\$approvalId: ID!) {
      circularPrefill(approvalId: \$approvalId) {
        approval { $_approvalFields }
        travelers { name passportNumber }
      }
    }
  ''');

  static final _submitDoc = gql(r'''
    mutation SubmitAirlineCircular(
      $approvalId: ID!, $flightNumber: String!, $flightDate: String!, $ticketFileName: String!, $ticketBase64: String!
    ) {
      submitAirlineCircular(
        approvalId: $approvalId, flightNumber: $flightNumber, flightDate: $flightDate,
        ticketFileName: $ticketFileName, ticketBase64: $ticketBase64
      ) { id }
    }
  ''');

  @override
  Future<Either<Failure, List<ApprovedSecurityRequest>>> approvedRequests() =>
      _graphQL.query<List<ApprovedSecurityRequest>>(
          QueryOptions<List<ApprovedSecurityRequest>>(
        document: _listDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => [
          for (final a in (j['approvedSecurityRequests'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
            _approval(a),
        ],
      ));

  @override
  Future<Either<Failure, CircularPrefill>> prefill(String approvalId) =>
      _graphQL.query<CircularPrefill>(QueryOptions<CircularPrefill>(
        document: _prefillDoc,
        variables: {'approvalId': approvalId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) {
          final p = j['circularPrefill'] as Map<String, dynamic>;
          return CircularPrefill(
            approval: _approval(p['approval'] as Map<String, dynamic>),
            travelers: [
              for (final t in (p['travelers'] as List<dynamic>)
                  .cast<Map<String, dynamic>>())
                CircularTraveler(
                    name: t['name'] as String? ?? '',
                    passportNumber: t['passportNumber'] as String? ?? ''),
            ],
          );
        },
      ));

  @override
  Future<Either<Failure, String>> submit(CircularSubmission submission) async {
    final List<int> bytes;
    try {
      bytes = await File(submission.ticket.path).readAsBytes();
    } catch (e) {
      return Left(ServerFailure(e.toString(), code: 'TICKET_UNREADABLE'));
    }
    final d = submission.flightDate;
    final date =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return _graphQL.mutate<String>(MutationOptions<String>(
      document: _submitDoc,
      variables: {
        'approvalId': submission.approvalId,
        'flightNumber': submission.flightNumber,
        'flightDate': date,
        'ticketFileName': submission.ticket.fileName,
        'ticketBase64': base64Encode(bytes),
      },
      parserFn: (j) =>
          (j['submitAirlineCircular'] as Map<String, dynamic>)['id'] as String,
    ));
  }
}

/// DEBUG ONLY: when a real call fails in a debug build, answers with the three approvals of the
/// Figma frame and accepts the submission. Release builds drop every branch (`kDebugMode` is a
/// compile-time constant). Nothing is persisted or sent.
class DebugFallbackAirlineCircularRepository
    implements AirlineCircularRepository {
  DebugFallbackAirlineCircularRepository(this._real);

  final AirlineCircularRepository _real;

  static final _approvals = [
    ApprovedSecurityRequest(
        id: 'a1',
        reference: 'SB-20451',
        leadName: 'محمد عبدالله الحميري',
        travelerCount: 3,
        issuedAt: DateTime(2026, 10, 2)),
    ApprovedSecurityRequest(
        id: 'a2',
        reference: 'SB-20433',
        leadName: 'خالد يحيى المقطري',
        travelerCount: 1,
        issuedAt: DateTime(2026, 9, 28)),
    ApprovedSecurityRequest(
        id: 'a3',
        reference: 'SB-20410',
        leadName: 'منى علي الشامي',
        travelerCount: 2,
        issuedAt: DateTime(2026, 9, 20)),
  ];

  @override
  Future<Either<Failure, List<ApprovedSecurityRequest>>>
      approvedRequests() async {
    final r = await _real.approvedRequests();
    return kDebugMode && r.isLeft() ? Right(_approvals) : r;
  }

  @override
  Future<Either<Failure, CircularPrefill>> prefill(String approvalId) async {
    final r = await _real.prefill(approvalId);
    if (kDebugMode && r.isLeft()) {
      final a = _approvals.firstWhere((x) => x.id == approvalId,
          orElse: () => _approvals.first);
      return Right(CircularPrefill(
        approval: a,
        travelers: [
          for (var i = 0; i < a.travelerCount; i++)
            CircularTraveler(
                name: i == 0 ? a.leadName : 'مسافر ${i + 1}',
                passportNumber: '0845${2197 + i * 6}'),
        ],
      ));
    }
    return r;
  }

  @override
  Future<Either<Failure, String>> submit(CircularSubmission submission) async {
    final r = await _real.submit(submission);
    return kDebugMode && r.isLeft() ? const Right('debug-circular') : r;
  }
}
