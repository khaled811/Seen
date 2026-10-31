// The unread-support count on Home's support button (design/gaps SUP-08): a violet pill with a
// white ring at the button's corner, "9+" above nine, hidden at zero.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/unread_tickets_cubit.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';

class SupportUnreadBadge extends StatefulWidget {
  const SupportUnreadBadge({super.key, required this.child, this.cubit});

  /// The support button.
  final Widget child;

  /// Test seam; defaults to the app's shared [UnreadTicketsCubit].
  final UnreadTicketsCubit? cubit;

  /// Reads the count again (after the support screens were left). Does nothing without a container.
  static void refresh() {
    try {
      InjectionContainer.instance.unreadTicketsCubit.refresh();
    } on Object {
      // No container in scope (a bare widget test).
    }
  }

  @override
  State<SupportUnreadBadge> createState() => _SupportUnreadBadgeState();
}

class _SupportUnreadBadgeState extends State<SupportUnreadBadge> with WidgetsBindingObserver {
  UnreadTicketsCubit? _cubit;

  @override
  void initState() {
    super.initState();
    try {
      _cubit = widget.cubit ?? InjectionContainer.instance.unreadTicketsCubit;
    } on Object {
      _cubit = null;
    }
    _cubit?.refresh();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit?.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) {
      return widget.child;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        PositionedDirectional(
          top: -4,
          end: -4,
          child: BlocBuilder<UnreadTicketsCubit, int>(
            bloc: cubit,
            builder: (context, count) => count <= 0 ? const SizedBox.shrink() : _Pill(count: count),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Semantics(
      label: SeenStrings.of(context).digits(l10n.supUnreadA11y(count)),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SeenBrand.violet,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.card, width: 2),
        ),
        child: Text(count > 9 ? SeenStrings.of(context).digits(l10n.supBadgeMax) : SeenStrings.of(context).numeral(count), style: type.chipS.copyWith(color: c.onPrimary, fontSize: 11, height: 16 / 11)),
      ),
    );
  }
}
