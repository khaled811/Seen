// "You do not have permission" view with the request-access action (Figma SYS-03),
// owning its AccessRequestCubit. Used by every section the role cannot open.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/system_state.dart';
import '../bloc/access_request_cubit.dart';

class AccessDeniedView extends StatelessWidget {
  const AccessDeniedView({super.key, required this.area, required this.message, required this.onBack, this.showRule = true});

  /// What was refused (`wallet`, `team`...), sent with the request.
  final String area;
  final String message;
  final VoidCallback onBack;
  final bool showRule;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createAccessRequestCubit(area),
      child: BlocConsumer<AccessRequestCubit, AccessRequestState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          final text = switch (state.status) {
            AccessRequestStatus.sent => s.accessRequestSent,
            AccessRequestStatus.failed => s.accessRequestFailed,
            _ => null,
          };
          if (text != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(text)));
          }
        },
        builder: (context, state) => SeenForbiddenView(
          icon: SeenIcons.gear,
          title: s.forbiddenTitle,
          message: message,
          requestLabel: s.requestAccess,
          requesting: state.status == AccessRequestStatus.sending,
          requested: state.status == AccessRequestStatus.sent,
          onRequest: () => context.read<AccessRequestCubit>().send(),
          backLabel: s.backToHome,
          onBack: onBack,
          rule: showRule ? s.visibilityRule : null,
        ),
      ),
    );
  }
}
