import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  group('TzPhone.tryParse', () {
    test('accepts the four forms people actually type', () {
      // All one person. The design is explicit that 0712… and 712… are the
      // same number.
      const forms = [
        '712345678',
        '0712345678',
        '712 345 678',
        '0712 345 678',
        '255712345678',
        '+255712345678',
        '+255 712 345 678',
        '+255-712-345-678',
      ];
      for (final form in forms) {
        final phone = TzPhone.tryParse(form);
        expect(phone, isNotNull, reason: 'should parse "$form"');
        expect(phone!.national, '712345678', reason: form);
      }
    });

    test('all of those forms compare equal', () {
      final a = TzPhone.tryParse('0712345678');
      final b = TzPhone.tryParse('+255 712 345 678');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('rejects too few and too many digits', () {
      expect(TzPhone.tryParse('71234567'), isNull, reason: '8 digits');
      expect(TzPhone.tryParse('7123456789'), isNull, reason: '10 digits');
      expect(TzPhone.tryParse('255'), isNull);
    });

    test('rejects empty and junk', () {
      expect(TzPhone.tryParse(null), isNull);
      expect(TzPhone.tryParse(''), isNull);
      expect(TzPhone.tryParse('   '), isNull);
      expect(TzPhone.tryParse('abcdefghi'), isNull);
      expect(TzPhone.tryParse('+++'), isNull);
    });

    test('rejects a normalised number starting with zero', () {
      // 0071234567 strips to 071234567, which is not a real number.
      expect(TzPhone.tryParse('0071234567'), isNull);
    });

    test('does not mistake a long number for a country code', () {
      // 255 followed by nine digits is a country code; 255 followed by six is
      // just a nine-digit number that happens to begin 255.
      expect(TzPhone.tryParse('255123456')?.national, '255123456');
    });

    test('accepts every operator prefix, present and future', () {
      // Deliberately not restricted: a prefix allow-list rejects a real
      // customer the day a new range is issued.
      for (final prefix in ['6', '7', '8', '9']) {
        expect(TzPhone.tryParse('${prefix}12345678'), isNotNull);
      }
    });
  });

  group('TzPhone formatting', () {
    final phone = TzPhone.tryParse('0712345678')!;

    test('e164 for Supabase Auth', () {
      expect(phone.e164, '+255712345678');
    });

    test('stored form matches the profiles.phone constraint', () {
      // The column checks ^255[0-9]{9}$.
      expect(phone.stored, '255712345678');
      expect(RegExp(r'^255[0-9]{9}$').hasMatch(phone.stored), isTrue);
    });

    test('formatted for display', () {
      expect(phone.formatted, '712 345 678');
    });

    test('masked hides the middle', () {
      expect(phone.masked, '712 ••• 678');
      expect(phone.masked, isNot(contains('345')));
    });
  });

  group('TzPhone.digitCount', () {
    test('counts what the number will be, not what was typed', () {
      // Typing the leading zero must not make the field look a digit further
      // along than it is -- that is what enables the Send button.
      expect(TzPhone.digitCount('0712345678'), 9);
      expect(TzPhone.digitCount('712345678'), 9);
      expect(TzPhone.digitCount('+255712345678'), 9);
      expect(TzPhone.digitCount('712 345 678'), 9);
    });

    test('counts partial input as it is typed', () {
      expect(TzPhone.digitCount(''), 0);
      expect(TzPhone.digitCount('7'), 1);
      expect(TzPhone.digitCount('0'), 1);
      expect(TzPhone.digitCount('07'), 1, reason: 'the 0 is not a digit of it');
      expect(TzPhone.digitCount('0712'), 3);
    });

    test('nine digits is exactly the threshold the button uses', () {
      expect(TzPhone.digitCount('71234567'), lessThan(TzPhone.nationalLength));
      expect(TzPhone.digitCount('712345678'), TzPhone.nationalLength);
      expect(TzPhone.isValid('712345678'), isTrue);
      expect(TzPhone.isValid('71234567'), isFalse);
    });
  });
}
