import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/branch_repository.dart';
import '../models/profile_dtos.dart';

Branch _branch(Map<String, dynamic> j) => Branch(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      staffCount: (j['staffCount'] as num?)?.toInt() ?? 0,
      requestCount: (j['requestCount'] as num?)?.toInt() ?? 0,
      parentId: j['parentId'] as String?,
    );

/// Raw GraphQL access to branches.
///
/// TODO(backend-contract): placeholder schema (`branches`, `branchStaff`, `createBranch`,
/// `assignMemberToBranch`); see docs/BACKEND_MIGRATION_GAPS.md section 43.
class BranchRemoteDataSource implements BranchRepository {
  BranchRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static const _fields = 'id name staffCount requestCount parentId';

  static final _listDoc = gql('query Branches { branches { $_fields } }');

  static final _staffDoc = gql(r'''
    query BranchStaff($branchId: ID!) { branchStaff(branchId: $branchId) { id name role } }
  ''');

  static final _createDoc = gql('''
    mutation CreateBranch(\$name: String!) { createBranch(name: \$name) { $_fields } }
  ''');

  static final _assignDoc = gql(r'''
    mutation AssignMemberToBranch($memberId: ID!, $branchId: ID!) {
      assignMemberToBranch(memberId: $memberId, branchId: $branchId) { success }
    }
  ''');

  @override
  Future<Either<Failure, List<Branch>>> list() => _graphQL.query<List<Branch>>(QueryOptions<List<Branch>>(
        document: _listDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => [for (final b in (j['branches'] as List<dynamic>).cast<Map<String, dynamic>>()) _branch(b)],
      ));

  @override
  Future<Either<Failure, List<BranchStaff>>> staff(String branchId) =>
      _graphQL.query<List<BranchStaff>>(QueryOptions<List<BranchStaff>>(
        document: _staffDoc,
        variables: {'branchId': branchId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => [
          for (final m in (j['branchStaff'] as List<dynamic>).cast<Map<String, dynamic>>())
            BranchStaff(id: m['id'] as String, name: m['name'] as String? ?? '', role: teamMemberFromJson(m).role),
        ],
      ));

  @override
  Future<Either<Failure, Branch>> create(String name) => _graphQL.mutate<Branch>(MutationOptions<Branch>(
        document: _createDoc,
        variables: {'name': name},
        parserFn: (j) => _branch(j['createBranch'] as Map<String, dynamic>),
      ));

  @override
  Future<Either<Failure, void>> assign({required String memberId, required String branchId}) async =>
      (await _graphQL.mutate<bool>(MutationOptions<bool>(
        document: _assignDoc,
        variables: {'memberId': memberId, 'branchId': branchId},
        parserFn: (j) => (j['assignMemberToBranch'] as Map<String, dynamic>?)?['success'] as bool? ?? true,
      )))
          .map((_) {});
}

/// DEBUG ONLY: when a real call fails in a debug build, answers from an in-memory copy of the
/// Figma sample so the screen can be used without a backend. Release builds drop every branch
/// (`kDebugMode` is a compile-time constant). Nothing is persisted.
class DebugFallbackBranchRepository implements BranchRepository {
  DebugFallbackBranchRepository(this._real);

  final BranchRepository _real;

  final _branches = <Branch>[
    const Branch(id: 'main', name: 'جُباري · الفرع الرئيسي', staffCount: 6, requestCount: 124),
    const Branch(id: 'sanaa', name: 'فرع صنعاء', staffCount: 3, requestCount: 52, parentId: 'main'),
    const Branch(id: 'aden', name: 'فرع عدن', staffCount: 2, requestCount: 41, parentId: 'main'),
    const Branch(id: 'taiz', name: 'فرع تعز', staffCount: 1, requestCount: 31, parentId: 'main'),
  ];
  final _staff = <String, List<BranchStaff>>{
    'main': [const BranchStaff(id: 'u1', name: 'Majd Alhakeem', role: TeamRole.owner)],
    'sanaa': [
      const BranchStaff(id: 'u3', name: 'هدى سالم', role: TeamRole.staff),
      const BranchStaff(id: 'u6', name: 'فهد العبسي', role: TeamRole.staff),
    ],
    'aden': [
      const BranchStaff(id: 'u2', name: 'وليد ناصر', role: TeamRole.branchManager),
      const BranchStaff(id: 'u7', name: 'سالم بن علي', role: TeamRole.staff),
    ],
    'taiz': [const BranchStaff(id: 'u4', name: 'أنور عبدالكريم', role: TeamRole.staff)],
  };
  int _next = 100;

  List<Branch> _counted() => [
        for (final b in _branches)
          Branch(
            id: b.id,
            name: b.name,
            staffCount: b.isMain ? _staff.values.fold(0, (a, l) => a + l.length) : (_staff[b.id]?.length ?? 0),
            requestCount: b.requestCount,
            parentId: b.parentId,
          ),
      ];

  @override
  Future<Either<Failure, List<Branch>>> list() async {
    final r = await _real.list();
    return kDebugMode && r.isLeft() ? Right(_counted()) : r;
  }

  @override
  Future<Either<Failure, List<BranchStaff>>> staff(String branchId) async {
    final r = await _real.staff(branchId);
    return kDebugMode && r.isLeft() ? Right(List.of(_staff[branchId] ?? const [])) : r;
  }

  @override
  Future<Either<Failure, Branch>> create(String name) async {
    final r = await _real.create(name);
    if (kDebugMode && r.isLeft()) {
      final b = Branch(id: 'b${_next++}', name: name, staffCount: 0, requestCount: 0, parentId: 'main');
      _branches.add(b);
      _staff[b.id] = [];
      return Right(b);
    }
    return r;
  }

  @override
  Future<Either<Failure, void>> assign({required String memberId, required String branchId}) async {
    final r = await _real.assign(memberId: memberId, branchId: branchId);
    if (kDebugMode && r.isLeft()) {
      BranchStaff? moved;
      for (final l in _staff.values) {
        final i = l.indexWhere((s) => s.id == memberId);
        if (i >= 0) {
          moved = l.removeAt(i);
          break;
        }
      }
      moved ??= BranchStaff(id: memberId, name: memberId, role: TeamRole.staff);
      (_staff[branchId] ??= []).add(moved);
      return const Right(null);
    }
    return r;
  }
}
