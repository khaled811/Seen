// Home for branch managers and staff (Figma ROLE-01): their role, the two things they
// can always do, why the wallet is missing, and what each role can do.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../requests/presentation/screens/requests_dashboard_screen.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../widgets/role_strings.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';

/// Capabilities shown in the differences table (profit margin is not one of them).
const roleTableRows = [
  Capability.createRequest,
  Capability.branchRequests,
  Capability.wallet,
  Capability.subAgents,
  Capability.team,
];

/// Columns of the table, in reading order after the label (owner first).
const roleTableColumns = [AgentPosition.owner, AgentPosition.branchManager, AgentPosition.staff];

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key, required this.position});

  final AgentPosition position;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final permissions = RolePermissions(position);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: s.roleHomeTitle(position), showBack: false),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: SeenBrand.violet05,
                        borderRadius: BorderRadius.all(SeenRadius.r14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [Text(s.roleOf(position), style: t.label)]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SeenButton(
                            label: AppLocalizations.of(context)!.homeRequestServiceAction,
                            expand: true,
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const ServiceSelectionScreen())),
                          ),
                        ),
                        const SizedBox(width: SeenSpace.s2),
                        Expanded(
                          child: SeenButton.secondary(
                            label: s.nav[1],
                            expand: true,
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const RequestsDashboardScreen())),
                          ),
                        ),
                      ],
                    ),
                    if (!permissions.can(Capability.wallet)) ...[
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: .6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: const BorderRadius.all(SeenRadius.r22),
                            border: Border.all(color: c.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(SeenIcons.lock, size: 16, color: c.inkMuted),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s.walletOwnerOnly, style: t.label.copyWith(color: c.inkMuted))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(s.roleDifferences, style: t.title),
                    const SizedBox(height: 12),
                    const RoleDifferencesTable(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who can do what, read from [RolePermissions] so it can never drift from the rules
/// the app really applies.
class RoleDifferencesTable extends StatelessWidget {
  const RoleDifferencesTable({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget cell(Widget child) => Expanded(child: Center(child: child));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        child: Column(
          children: [
            ColoredBox(
              color: SeenBrand.violet05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    for (final r in roleTableColumns)
                      cell(Text(s.roleShort(r), style: t.caption.copyWith(color: c.inkMuted))),
                  ],
                ),
              ),
            ),
            for (final cap in roleTableRows)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(s.capabilityLabel(cap), style: t.caption.copyWith(color: c.ink))),
                      for (final r in roleTableColumns)
                        cell(
                          Semantics(
                            label: RolePermissions.roleCan(r, cap) ? s.roleTableYes : s.roleTableNo,
                            child: RolePermissions.roleCan(r, cap)
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: SeenRequestStatus.completed.colors.fg,
                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                    ),
                                    child: SeenCheckGlyph(size: 14, color: c.onPrimary),
                                  )
                                : Text('—', style: t.label.copyWith(color: c.inkMuted)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
