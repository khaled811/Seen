import 'package:flutter/material.dart';

/// A destination in the agent workspace's bottom bar. The shell does not know
/// the agent features; the app supplies the tabs.
///
/// A tab either shows a page inside the shell ([builder]; the bar stays and
/// the page is kept alive once opened) or runs an action such as opening the
/// account sheet ([onTap]).
class AgentTab {
  const AgentTab({
    required this.icon,
    required this.label,
    this.builder,
    this.onTap,
  }) : assert(
          (builder == null) != (onTap == null),
          'give either a page builder or an action',
        );

  final IconData icon;
  final String label;
  final WidgetBuilder? builder;

  /// Called with the shell's context.
  final void Function(BuildContext context)? onTap;
}
