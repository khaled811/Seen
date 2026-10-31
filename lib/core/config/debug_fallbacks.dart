import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;

/// Single switch for the `DebugFallback*` data-source decorators.
///
/// The decorators replace a *failed* real call with canned data so screens can
/// be looked at before the backend exists. That also hides real contract
/// failures (`validation_failed`, `permission_denied`, a wrong operation name),
/// so they are **off by default** and must be asked for explicitly:
///
///     flutter run --dart-define=USE_DEBUG_FALLBACKS=true
///
/// Never true in a release or profile-less production build: [kDebugMode] is
/// checked first, so no define can enable it there.
abstract final class DebugFallbacks {
  static const bool _requested = bool.fromEnvironment('USE_DEBUG_FALLBACKS');

  /// Test hook. Null means "follow the build define".
  @visibleForTesting
  static bool? testOverride;

  static bool get enabled => kDebugMode && (testOverride ?? _requested);
}

/// Read by every fallback decorator in place of `kDebugMode`.
bool get debugFallbacksEnabled => DebugFallbacks.enabled;
