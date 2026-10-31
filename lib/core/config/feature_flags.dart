// Compile-time feature flags.

/// The "Spiritual & Manasik Hub" (`lib/features/spiritual/`): the dual-mode
/// shell with the flip to سين المناسك. Dormant until its release phase: while
/// false the app launches straight into the agent home, with no mode switcher
/// and no spiritual routes reachable. The module's code, assets and tests stay
/// in place and are tested directly.
const bool kEnableSpiritualHub = false;

/// Home promo banner. Its content comes from the server (`activeAds`); nothing is
/// shown when the server offers no ad. Flip to false to hide the slot entirely.
const bool kShowHomePromoBanner = true;

/// "Scan the passport" on the traveler form (`POST /files/read-passport/`). Flip to false to hide the
/// button; the form then works exactly as before.
const bool kEnablePassportScan = true;
