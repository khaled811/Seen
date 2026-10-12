import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/chrome.dart';
import '../../../agents/presentation/screens/sub_agents_list_screen.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../requests/presentation/screens/requests_dashboard_screen.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import 'home_screen.dart';

/// The agent workspace's frame: [HomeScreen] plus requests, wallet and
/// sub-agents as tabs of a bottom navigation bar; the fifth tab opens the
/// account sheet.
///
/// A tab is built the first time it is opened and then kept alive (scroll
/// position and loaded data survive); hidden tabs have their tickers paused.
/// System back on any other tab returns to Home first.
class AgentShell extends StatefulWidget {
  const AgentShell({
    super.key,
    required this.session,
    this.pageBuilders,
    this.onAccount,
  });

  final UserSession session;

  /// Replaces the four pages (home, requests, wallet, sub-agents); tests use
  /// stubs because the real screens talk to the network.
  @visibleForTesting
  final List<WidgetBuilder>? pageBuilders;

  /// Replaces opening the account sheet (tests).
  @visibleForTesting
  final void Function(BuildContext context)? onAccount;

  @override
  State<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<AgentShell> {
  static const _account = 4;

  /// 0 home, 1 requests, 2 wallet, 3 sub-agents.
  int _index = 0;
  final _opened = <int>{0};

  Widget _page(int i) => widget.pageBuilders != null
      ? widget.pageBuilders![i](context)
      : _defaultPage(i);

  Widget _defaultPage(int i) => switch (i) {
        0 => HomeScreen(session: widget.session),
        1 => const RequestsDashboardScreen(),
        2 => const WalletScreen(embedded: true),
        _ => const SubAgentsListScreen(embedded: true),
      };

  void _select(int i) {
    if (i == _account) {
      (widget.onAccount ?? showAccountSheet)(context);
      return;
    }
    setState(() {
      _index = i;
      _opened.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvoked: (didPop) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < 4; i++)
              TickerMode(
                enabled: i == _index,
                child: _opened.contains(i) ? _page(i) : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: SeenBottomNav(
          selectedIndex: _index,
          onSelected: _select,
        ),
      ),
    );
  }
}
