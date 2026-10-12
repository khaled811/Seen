import 'package:flutter/material.dart';

import 'agent_tab.dart';

/// The agent side of the flip: [home] plus the page tabs, switched from the
/// bottom bar. A tab is built the first time it is opened and then kept
/// alive (so its scroll position and loaded data survive); hidden tabs have
/// their tickers paused.
class AgentFace extends StatefulWidget {
  const AgentFace({
    super.key,
    required this.home,
    required this.tabs,
    required this.index,
  });

  final Widget home;

  /// The bar's tabs after home; only those with a builder are pages.
  final List<AgentTab> tabs;

  /// 0 = home, i = tabs[i - 1].
  final int index;

  @override
  State<AgentFace> createState() => _AgentFaceState();
}

class _AgentFaceState extends State<AgentFace> {
  final _opened = <int>{0};

  @override
  Widget build(BuildContext context) {
    _opened.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i <= widget.tabs.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: !_opened.contains(i)
                ? const SizedBox.shrink()
                : i == 0
                    ? widget.home
                    : (widget.tabs[i - 1].builder?.call(context) ??
                        const SizedBox.shrink()),
          ),
      ],
    );
  }
}
