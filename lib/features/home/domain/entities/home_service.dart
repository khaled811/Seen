import 'package:equatable/equatable.dart';

/// One service shortcut on the home screen (`portalHome.services`), named in the
/// language the app shows. Pure Dart.
class HomeService extends Equatable {
  const HomeService({required this.id, required this.name, required this.category});

  final String id;
  final String name;

  /// The server's category word; the screen picks an icon from it (unknown ones get a generic icon).
  final String category;

  @override
  List<Object?> get props => [id, name, category];
}
