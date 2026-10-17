// Maintenance mode (Figma SYS-04): the server is down on purpose; say when it is
// expected back and let the user check again.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/system_state.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen(
      {super.key,
      required this.eta,
      required this.checking,
      required this.onRetry,
      this.now});

  final DateTime? eta;
  final bool checking;
  final VoidCallback onRetry;

  /// Tests pin the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final at = now ?? DateTime.now();
    final eta = this.eta;
    return Scaffold(
      body: SeenScreenBackground(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: SeenSystemMessage(
                    illustration:
                        SeenSystemIllustration(icon: SeenIcons.gear),
                    title: s.maintenanceTitle,
                    body: s.maintenanceBody(eta, at),
                    below: [
                      if (eta != null) ...[
                        const SizedBox(height: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: SeenRequestStatus.underReview.colors.bg,
                            borderRadius:
                                const BorderRadius.all(SeenRadius.full),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Row(
                              children: [
                                Text(
                                  s.maintenanceEtaChip(eta),
                                  style: t.caption.copyWith(
                                    color:
                                        SeenRequestStatus.underReview.colors.fg,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SeenActionBar(
              actions: [
                SeenButton.secondary(
                    label: s.retryAction,
                    expand: true,
                    loading: checking,
                    onPressed: onRetry)
              ],
            ),
          ],
        ),
      ),
    );
  }
}
