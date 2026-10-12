import 'dua.dart';

/// The chips above the dua library. [saved] is the favourites view; every
/// other value maps to a [DuaCategory] (or none, for [all]).
enum DuaFilter {
  all(null),
  hajj(DuaCategory.hajj),
  safar(DuaCategory.safar),
  adhkar(DuaCategory.adhkar),
  jawami(DuaCategory.jawami),
  saved(null);

  const DuaFilter(this.category);

  final DuaCategory? category;

  bool matches(Dua dua, Set<String> favorites) => switch (this) {
        DuaFilter.all => true,
        DuaFilter.saved => favorites.contains(dua.id),
        _ => dua.category == category,
      };
}
