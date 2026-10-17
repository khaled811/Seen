// Required update (Figma SYS-05, hard): this version is blocked; the only way on is
// the store.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/system_state.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.onUpdate});

  /// Opens the store; null when the server sent no link (the button is disabled).
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
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
                        SeenSystemIllustration(icon: SeenIcons.upload),
                    title: s.updateRequiredTitle,
                    body: s.updateRequiredBody,
                  ),
                ),
              ),
            ),
            SeenActionBar(actions: [
              SeenButton(
                  label: s.updateFromStore, expand: true, onPressed: onUpdate)
            ]),
          ],
        ),
      ),
    );
  }
}
