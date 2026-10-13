// Bundled Figma SVG asset paths (render with flutter_svg's SvgPicture.asset).
// Brand logos, hero art and patterns live in assets/vectors/, the custom Figma
// icon set in assets/icons/. Phosphor (SeenIcons) stays the fallback icons.
abstract final class SeenVectors {
  /// Seen Business vertical lockup (dark). Splash.
  static const logoVertical = 'assets/vectors/logo_vertical.svg';

  /// Seen Business horizontal lockup (dark). Auth headers.
  static const logoPrimary = 'assets/vectors/logo_primary.svg';

  /// Welcome hero card (350x300 card inside a 422x372 canvas; the Figma drop
  /// shadow is removed from the file and drawn natively).
  static const welcomeHero = 'assets/vectors/welcome_hero.svg';

  /// Seen Business horizontal lockup, all white (on violet cards).
  static const logoWhite = 'assets/vectors/logo_white.svg';

  /// Isometric brand pattern, white at 20% (balance card corner).
  static const patternIsometricWhite = 'assets/vectors/pattern_isometric_white.svg';

  /// Brand grid pattern, violet at 10% fading at the edges (promo banner).
  static const patternGridPromo = 'assets/vectors/pattern_grid_promo.svg';

  /// Icon/chat (36px glyph on the OTP header tile).
  static const iconChat = 'assets/icons/icon_chat.svg';

  // Bottom-navigation icons (single-color glyphs, tinted per state).
  static const iconHome = 'assets/icons/icon_home.svg';
  static const iconRequests = 'assets/icons/icon_requests.svg';
  static const iconWallet = 'assets/icons/icon_wallet.svg';
  static const iconAgents = 'assets/icons/icon_agents.svg';
  static const iconAccount = 'assets/icons/icon_account.svg';

  // Account screen (Figma 14 · node 18:835), exported from the Figma icon set.
  static const accountChevron = 'assets/icons/account/chevron.svg';
  static const accountDocument = 'assets/icons/account/document.svg';
  static const accountCash = 'assets/icons/account/cash.svg';
  static const accountAgents = 'assets/icons/account/agents.svg';
  static const accountBell = 'assets/icons/account/bell.svg';
  static const accountSettings = 'assets/icons/account/settings.svg';
  static const accountSupport = 'assets/icons/account/support.svg';
  static const accountLogout = 'assets/icons/account/logout.svg';

  // Wallet top-up (Figma 12 · node 18:619).
  static const walletIcon = 'assets/icons/wallet/wallet.svg';
  static const walletCash = 'assets/icons/wallet/cash.svg';
  static const walletBank = 'assets/icons/wallet/bank.svg';
  static const walletCheck = 'assets/icons/wallet/check.svg';
  static const walletPatternGrid = 'assets/icons/wallet/pattern_grid.svg';

  // Search field icon (Figma 08 · node 16:392).
  static const catalogSearch = 'assets/icons/catalog/search.svg';

  // Sub-agents screen (Figma 13 · node 18:722).
  static const agentsSearch = 'assets/icons/agents/search.svg';
  static const agentsPlus = 'assets/icons/agents/plus.svg';

  // Service icons (violet tiles with a knocked-out glyph).
  static const iconFlight = 'assets/icons/icon_flight.svg';
  static const iconSaudiVisa = 'assets/icons/icon_saudi_visa.svg';
  static const iconEgyptEntry = 'assets/icons/icon_egypt_entry.svg';
  static const iconJordanSecurity = 'assets/icons/icon_jordan_security.svg';
  static const iconIndiaVisa = 'assets/icons/icon_india_visa.svg';
  static const iconHotel = 'assets/icons/icon_hotel.svg';
}
