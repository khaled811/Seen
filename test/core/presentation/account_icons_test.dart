// The Figma account icons are bundled, non-empty SVGs.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/foundation/seen_vectors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every account icon asset is bundled and is an SVG', () async {
    const assets = [
      SeenVectors.accountChevron,
      SeenVectors.accountDocument,
      SeenVectors.accountCash,
      SeenVectors.accountAgents,
      SeenVectors.accountBell,
      SeenVectors.accountSettings,
      SeenVectors.accountSupport,
      SeenVectors.accountLogout,
    ];
    for (final a in assets) {
      final svg = await rootBundle.loadString(a);
      expect(svg.trimLeft().startsWith('<svg'), isTrue, reason: a);
      expect(svg.length, greaterThan(100), reason: a);
    }
  });
}
