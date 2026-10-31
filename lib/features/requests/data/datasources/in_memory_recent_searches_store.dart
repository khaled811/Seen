import '../../domain/repositories/recent_searches_store.dart';

/// Recent request searches, kept in process memory only.
///
/// A search can contain a traveler's name, so it is never written to the device
/// (`docs/implementation/DECISIONS.md` P-02). The store is emptied on logout.
class InMemoryRecentSearchesStore implements RecentSearchesStore {
  List<String> _items = const [];

  @override
  Future<List<String>> read() async => List.of(_items);

  @override
  Future<List<String>> remember(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return read();
    _items = [
      clean,
      for (final q in _items)
        if (q.toLowerCase() != clean.toLowerCase()) q,
    ].take(RecentSearchesStore.maxItems).toList();
    return List.of(_items);
  }

  @override
  Future<void> clear() async => _items = const [];
}
