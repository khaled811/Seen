import 'package:equatable/equatable.dart';

/// How to reach support before signing in (Figma SUP-05). Any channel can be
/// missing; [hours] is shown as written ("8 am to 10 pm").
class SupportContacts extends Equatable {
  const SupportContacts({this.whatsapp, this.phone, this.email, this.hours});

  final String? whatsapp;
  final String? phone;
  final String? email;
  final String? hours;

  bool get hasChannels => _has(whatsapp) || _has(phone) || _has(email);

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  List<Object?> get props => [whatsapp, phone, email, hours];
}
