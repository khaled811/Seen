import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/access_token_store.dart';

void main() {
  test('holds the token in memory and changes generation on every set and clear', () {
    final store = AccessTokenStore();
    expect(store.hasToken, isFalse);
    final g0 = store.generation;

    store.set('a');
    expect(store.token, 'a');
    expect(store.generation, isNot(g0));

    final g1 = store.generation;
    store.set('b');
    expect(store.generation, isNot(g1));

    final g2 = store.generation;
    store.clear();
    expect(store.hasToken, isFalse);
    expect(store.generation, isNot(g2));
  });

  test('a token is stale from 13 minutes on, never when absent', () {
    var now = DateTime(2026, 10, 19, 9);
    final store = AccessTokenStore(clock: () => now);
    expect(store.isStale, isFalse);

    store.set('a');
    now = now.add(const Duration(minutes: 12, seconds: 59));
    expect(store.isStale, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(store.isStale, isTrue);

    store.set('b');
    expect(store.isStale, isFalse);
    store.clear();
    now = now.add(const Duration(hours: 1));
    expect(store.isStale, isFalse);
  });
}
