import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/recent_searches_store.dart';

/// The recent request searches (Figma REQ-13), newest first. A new list is
/// emitted on every change.
class RecentSearchesCubit extends Cubit<List<String>> {
  RecentSearchesCubit(this._store) : super(const []);

  final RecentSearchesStore _store;

  Future<void> load() async {
    final items = await _store.read();
    if (!isClosed) emit(items);
  }

  Future<void> remember(String query) async {
    final items = await _store.remember(query);
    if (!isClosed) emit(items);
  }

  Future<void> clear() async {
    await _store.clear();
    if (!isClosed) emit(const []);
  }
}
