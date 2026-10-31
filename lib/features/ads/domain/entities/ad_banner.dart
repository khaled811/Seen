import 'package:equatable/equatable.dart';

/// Where an ad button leads inside the app. The server only sends paths from a fixed list of web
/// routes (`/agent/services`, `/agent/requests`, `/agent/wallet`, `/agent/tickets`,
/// `/agent/sub-agents`, `/agent/employees`; `/agent/dashboard` and `/agent/security` have no
/// separate screen here); the app maps each to its own screen.
enum AdDestination { services, requests, wallet, tickets, subAgents, team }

/// One promotion the server chose for the home screen (`activeAds`,
/// `placement: home_banner`), already in the language the app shows. Pure Dart.
class AdBanner extends Equatable {
  const AdBanner({required this.id, required this.title, required this.body, this.ctaLabel = '', this.ctaLink = ''});

  final String id;
  final String title;
  final String body;

  /// The button text and where it leads. Both may be empty: then there is no button.
  final String ctaLabel;
  final String ctaLink;

  /// A link the app opens outside itself. Only `https` is followed: anything else
  /// (another scheme, a path the app has no route for) is not opened.
  Uri? get openableLink {
    final uri = Uri.tryParse(ctaLink.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
  }

  /// The app screen a web path (`/agent/...`) stands for, or null (another path, or one with no screen here).
  AdDestination? get internalDestination {
    final link = ctaLink.trim();
    if (!link.startsWith('/') || link.startsWith('//')) return null;
    final path = Uri.tryParse(link)?.path;
    return switch (path) {
      '/agent/services' => AdDestination.services,
      '/agent/requests' => AdDestination.requests,
      '/agent/wallet' => AdDestination.wallet,
      '/agent/tickets' => AdDestination.tickets,
      '/agent/sub-agents' => AdDestination.subAgents,
      '/agent/employees' => AdDestination.team,
      _ => null,
    };
  }

  /// The button shows only when it has a label and somewhere to go: a link the app can open
  /// outside itself, or a screen of its own.
  bool get hasAction => ctaLabel.trim().isNotEmpty && (openableLink != null || internalDestination != null);

  @override
  List<Object?> get props => [id, title, body, ctaLabel, ctaLink];
}
