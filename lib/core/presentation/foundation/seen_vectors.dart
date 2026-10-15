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
  static const walletClock = 'assets/icons/wallet/clock.svg';
  static const walletTxnBank = 'assets/icons/wallet/txn_bank.svg';
  static const walletTxnTransfer = 'assets/icons/wallet/txn_transfer.svg';
  static const walletPatternGrid = 'assets/icons/wallet/pattern_grid.svg';

  // Search field icon (Figma 08 · node 16:392).
  static const catalogSearch = 'assets/icons/catalog/search.svg';

  // Booking review (Figma 10 · node 16:545).
  static const reviewPatternIsometric = 'assets/icons/review/pattern_isometric.svg';
  static const reviewWallet = 'assets/icons/review/wallet.svg';
  static const reviewCheckboxChecked = 'assets/icons/review/checkbox_checked.svg';

  // Requests header (Figma 06 · node 11:241).
  static const requestsPlus = 'assets/icons/requests/plus.svg';
  static const viewerShare = 'assets/icons/requests/viewer_share.svg';
  static const viewerClock = 'assets/icons/requests/viewer_clock.svg';
  static const viewerAlert = 'assets/icons/requests/viewer_alert.svg';
  static const sessionClock = 'assets/icons/requests/session_clock.svg';
  static const successCheck = 'assets/icons/requests/success_check.svg';
  static const infoReview = 'assets/icons/requests/info_review.svg';
  static const missingDocTile = 'assets/icons/requests/missing_doc_tile.svg';
  static const sourceFile = 'assets/icons/requests/source_file.svg';
  static const sourceGallery = 'assets/icons/requests/source_gallery.svg';
  static const sourceCamera = 'assets/icons/requests/source_camera.svg';
  static const previewDoc = 'assets/icons/requests/preview_doc.svg';

  // Create agency account (Figma 15 · node 20:594).
  static const authClock = 'assets/icons/auth/clock.svg';
  static const authUpload = 'assets/icons/auth/upload.svg';

  // Notifications (Figma 17 · node 20:697).
  static const notifCheck = 'assets/icons/notifications/check.svg';
  static const notifAlert = 'assets/icons/notifications/alert.svg';
  static const notifWallet = 'assets/icons/notifications/wallet.svg';
  static const notifReview = 'assets/icons/notifications/review.svg';
  static const notifAgents = 'assets/icons/notifications/agents.svg';

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
