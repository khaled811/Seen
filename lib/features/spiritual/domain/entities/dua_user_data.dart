import 'package:equatable/equatable.dart';

import 'dua_filter.dart';

/// What the user keeps about the dua library: saved duas and the last chip.
class DuaUserData extends Equatable {
  const DuaUserData({this.favorites = const {}, this.filter = DuaFilter.all});

  final Set<String> favorites;
  final DuaFilter filter;

  @override
  List<Object?> get props => [favorites, filter];
}
