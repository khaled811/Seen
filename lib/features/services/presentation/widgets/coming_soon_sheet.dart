// "Service coming soon" (Figma BOOK-09): what is being built, and a way to be told when it
// launches. Opened by tapping a service that is not bookable yet.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/service_interest_cubit.dart';

/// [serviceKey] identifies the service to the server; [name] is shown ("Hotel booking");
/// [icon] is its glyph. [createCubit] is a test seam.
Future<void> showServiceComingSoonSheet(
  BuildContext context, {
  required String serviceKey,
  required String name,
  required IconData icon,
  ServiceInterestCubit Function()? createCubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => (createCubit ?? () => InjectionContainer.instance.createServiceInterestCubit(serviceKey))(),
      child: _Body(name: name, icon: icon),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return BlocBuilder<ServiceInterestCubit, ServiceInterestState>(
      builder: (context, state) {
        final done = state.status == InterestStatus.registered;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(19))),
                  child: SizedBox(width: 64, height: 64, child: Icon(icon, size: 36, color: SeenBrand.violet)),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.comingSoonTitle(name), textAlign: TextAlign.center, style: t.h2),
              const SizedBox(height: 8),
              Text(s.comingSoonBody(name), textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
              if (done) ...[
                const SizedBox(height: 16),
                SeenInlineBanner(tone: SeenBannerTone.ok, message: s.comingSoonRegistered),
              ],
              if (state.status == InterestStatus.failed) ...[
                const SizedBox(height: 16),
                SeenInlineBanner(tone: SeenBannerTone.error, message: s.comingSoonFailed),
              ],
              if (state.status == InterestStatus.unavailable) ...[
                const SizedBox(height: 16),
                SeenInlineBanner(tone: SeenBannerTone.warn, message: s.comingSoonUnavailable),
              ],
              const SizedBox(height: 16),
              SeenButton(
                label: s.notifyMeAction,
                expand: true,
                loading: state.status == InterestStatus.sending,
                onPressed: done || state.status == InterestStatus.sending || state.status == InterestStatus.unavailable ? null : () => context.read<ServiceInterestCubit>().notify(),
              ),
              const SizedBox(height: 8),
              SeenButton.ghost(label: s.closeAction, expand: true, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        );
      },
    );
  }
}
