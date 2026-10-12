import 'package:equatable/equatable.dart';

/// Where the user last stopped reading.
class LastRead extends Equatable {
  const LastRead({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  List<Object?> get props => [surah, ayah];
}
