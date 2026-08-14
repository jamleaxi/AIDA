import 'package:aida/utils/philippine_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhilippineTime', () {
    test('adds a fixed 8-hour offset to a UTC time', () {
      final utc = DateTime.utc(2026, 8, 14, 10, 0);

      final result = utc.toPhilippineTime;

      expect(result, DateTime.utc(2026, 8, 14, 18, 0));
    });

    test('converts a local time to UTC before applying the offset', () {
      final local = DateTime(2026, 8, 14, 10, 0);
      final expected = local.toUtc().add(const Duration(hours: 8));

      expect(local.toPhilippineTime, expected);
    });

    test('rolls over into the next day near midnight UTC', () {
      final utc = DateTime.utc(2026, 8, 14, 20, 0);

      final result = utc.toPhilippineTime;

      expect(result, DateTime.utc(2026, 8, 15, 4, 0));
    });
  });
}
