// Compile-time feature flags.

/// The "Spiritual & Manasik Hub" (`lib/features/spiritual/`): the dual-mode
/// shell with the flip to سين المناسك. Dormant until its release phase: while
/// false the app launches straight into the agent home, with no mode switcher
/// and no spiritual routes reachable. The module's code, assets and tests stay
/// in place and are tested directly.
const bool kEnableSpiritualHub = false;

/// Home promo banner. The banner is static placeholder copy until a backend
/// banner/announcement API exists; flip to false to hide it.
const bool kShowHomePromoBanner = true;
