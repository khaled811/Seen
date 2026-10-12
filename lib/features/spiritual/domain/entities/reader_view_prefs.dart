import 'package:equatable/equatable.dart';

/// How the user likes to read: ayah by ayah (list) or as mushaf pages.
class ReaderViewPrefs extends Equatable {
  const ReaderViewPrefs({this.pages = false});

  final bool pages;

  ReaderViewPrefs copyWith({bool? pages}) =>
      ReaderViewPrefs(pages: pages ?? this.pages);

  @override
  List<Object?> get props => [pages];
}
