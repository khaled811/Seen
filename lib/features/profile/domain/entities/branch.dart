import 'package:equatable/equatable.dart';

import 'team_member.dart';

/// One branch of the agency (Figma ACC-07). The main branch has no parent; the others hang
/// under it.
class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    this.staffCount,
    this.requestCount,
    this.parentId,
  });

  final String id;
  final String name;
  /// The API does not count a branch's people or requests; null = not known.
  final int? staffCount;
  final int? requestCount;
  final String? parentId;

  bool get isMain => parentId == null;

  @override
  List<Object?> get props => [id, name, staffCount, requestCount, parentId];
}

/// A person working in a branch.
class BranchStaff extends Equatable {
  const BranchStaff({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final TeamRole role;

  @override
  List<Object?> get props => [id, name, role];
}
