import 'package:flutter/foundation.dart';

/// Which branch's requests the agent is looking at (Figma ACC-07 "view requests by
/// branch"): `null` = all branches. One app-wide value; the requests query reads it and
/// the requests screen reloads when it changes. Held in memory only.
class BranchScope extends ValueNotifier<String?> {
  BranchScope() : super(null);

  static final BranchScope shared = BranchScope();
}
