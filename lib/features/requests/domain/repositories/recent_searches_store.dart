/// The agent's last request searches (Figma REQ-13). They can hold traveler
/// names, so implementations must keep them in memory only (never on the
/// device), drop them when the session ends, and the UI lets the agent clear them.
abstract interface class RecentSearchesStore {
  /// Newest first, at most [maxItems].
  Future<List<String>> read();

  /// Puts [query] first (moving it up when already there) and trims the list.
  Future<List<String>> remember(String query);

  Future<void> clear();

  static const maxItems = 5;
}
