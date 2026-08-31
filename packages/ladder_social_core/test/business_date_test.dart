import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

void main() {
  test('DateOnly serialization preserves calendar components', () {
    final DateTime value = DateTime.utc(2026, 8, 31, 23, 30);

    expect(dateOnlyString(value), '2026-08-31');
  });

  test('UTC business date is derived from the same instant on every client', () {
    final DateTime instant = DateTime.parse('2026-08-31T23:30:00-05:00');

    expect(utcBusinessDate(instant), DateTime(2026, 9, 1));
    expect(
      utcCalendarDate(DateTime.parse('2026-08-31T23:59:59Z')),
      DateTime(2026, 8, 31),
    );
  });
}
