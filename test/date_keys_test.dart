import 'package:flutter_reading_portfolio_app/core/utils/date_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats dates as yyyymmdd', () {
    expect(convertDateTimeToString(DateTime(2026, 6, 4)), '20260604');
  });

  test('parses yyyymmdd keys into date-only objects', () {
    final date = createDateTimeObject('20260604');

    expect(date.year, 2026);
    expect(date.month, 6);
    expect(date.day, 4);
  });
}
