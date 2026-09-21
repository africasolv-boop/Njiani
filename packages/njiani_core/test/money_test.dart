import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  group('groupDigits', () {
    test('leaves values under a thousand alone', () {
      expect(groupDigits(0), '0');
      expect(groupDigits(500), '500');
      expect(groupDigits(999), '999');
    });

    test('groups thousands', () {
      expect(groupDigits(1000), '1,000');
      expect(groupDigits(1500), '1,500');
      expect(groupDigits(12500), '12,500');
      expect(groupDigits(999999), '999,999');
    });

    test('groups millions', () {
      expect(groupDigits(1000000), '1,000,000');
      expect(groupDigits(4500000), '4,500,000');
    });

    test('handles negatives', () {
      expect(groupDigits(-1500), '-1,500');
    });
  });

  group('tsh', () {
    test('formats fares the way the pitch deck does', () {
      expect(tsh(1000), 'TSh 1,000');
      expect(tsh(1500), 'TSh 1,500');
      expect(tsh(4500), 'TSh 4,500');
    });

    test('never shows a decimal part', () {
      // Fares are whole shillings; a decimal would be a bug, not a rounding.
      for (final amount in [1, 999, 1000, 250000]) {
        expect(tsh(amount), isNot(contains('.')));
      }
    });
  });
}
