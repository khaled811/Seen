import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/utils/masking.dart';

void main() {
  test('keepLast4 shows the last four and never the length', () {
    expect(Masking.keepLast4('N08494821'), '••••••4821');
    expect(Masking.keepLast4('N0849482100000'), '••••••0000');
    expect(Masking.keepLast4('abc'), '••••••');
  });

  test('email keeps two letters and the domain', () {
    expect(Masking.email('sara.a@mail.com'), 'sa•••••@mail.com');
    expect(Masking.email('nomail'), '••••••mail');
  });

  test('phone keeps the country code, the first local digit and the last three', () {
    expect(Masking.phone('+966 512 345 214'), '+966 5•• ••• 214');
    expect(Masking.phone('0512345214'), '5•• ••• 214');
    expect(Masking.phone('123'), '••••••');
  });
}
