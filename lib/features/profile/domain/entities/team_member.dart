import 'package:equatable/equatable.dart';

/// Roles a team member can hold (Figma ACC-03). Pure Dart.
enum TeamRole { owner, branchManager, staff }

enum TeamMemberStatus { active, invited, disabled }

class TeamMember extends Equatable {
  const TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.branchName,
  });

  final String id;
  final String name;
  final TeamRole role;
  final TeamMemberStatus status;

  /// null = all branches (the owner).
  final String? branchName;

  /// The owner is fixed: not edited, not disabled here.
  bool get isOwner => role == TeamRole.owner;

  @override
  List<Object?> get props => [id, name, role, status, branchName];
}

/// What the add-user sheet collects: the contract's `StaffUserInput` (e-mail, full name,
/// first password, position, optional branch).
class InviteDraft extends Equatable {
  const InviteDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.branchName = '',
    this.branchId,
  });

  final String name;
  final String email;

  /// The user's first password, set by whoever adds them. It travels once with the
  /// request and is not part of equality.
  final String password;
  final TeamRole role;
  final String branchName;

  /// Set when the branch was picked from the real list (Figma ACC-07); null = no branch.
  final String? branchId;

  @override
  List<Object?> get props => [name, email, role, branchName, branchId];
}
