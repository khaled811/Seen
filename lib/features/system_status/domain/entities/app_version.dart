import 'package:equatable/equatable.dart';

/// A dotted version such as `2.5.1` (a `+build` or `-tag` suffix is ignored).
/// Pure Dart; compares numerically segment by segment, so 2.10 > 2.9.
class AppVersion extends Equatable implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  /// null when [raw] is not a dotted number (a malformed server value must
  /// never block the app).
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final core = raw.trim().split(RegExp(r'[+\-]')).first;
    if (core.isEmpty) return null;
    final parts = <int>[];
    for (final p in core.split('.')) {
      final n = int.tryParse(p);
      if (n == null) return null;
      parts.add(n);
    }
    return AppVersion(parts);
  }

  @override
  int compareTo(AppVersion other) {
    final length =
        parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  List<Object?> get props => [parts];

  @override
  String toString() => parts.join('.');
}
