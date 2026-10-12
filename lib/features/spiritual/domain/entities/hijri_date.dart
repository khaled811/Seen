import 'package:equatable/equatable.dart';

/// Arabic names of the twelve Hijri months (index 0 = المحرم).
const hijriMonthNames = [
  'المحرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

class HijriDate extends Equatable {
  const HijriDate({
    required this.day,
    required this.monthName,
    required this.year,
    this.month = 0,
  });

  final int day;

  /// Arabic month name, e.g. "ربيع الآخر".
  final String monthName;
  final int year;

  /// 1..12, or 0 when unknown (fixtures).
  final int month;

  @override
  List<Object?> get props => [day, monthName, year, month];
}
