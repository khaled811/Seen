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

/// What the invite sheet collects.
class InviteDraft extends Equatable {
  const InviteDraft({required this.name, required this.phone, required this.role, required this.branchName, this.branchId});

  final String name;
  final String phone;
  final TeamRole role;
  final String branchName;

  /// Set when the branch was picked from the real list (Figma ACC-07); null when typed.
  final String? branchId;

  @override
  List<Object?> get props => [name, phone, role, branchName, branchId];
}
