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

  /// Icon/chat (36px glyph on the OTP header tile).
  static const iconChat = 'assets/icons/icon_chat.svg';
}
