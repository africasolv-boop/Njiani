/// Tanzanian shilling formatting.
///
/// Hand-rolled rather than pulled from `intl`: the only rule needed is
/// thousands grouping, and the pitch deck's prototype formats the same way.
library;

/// Formats [amount] as a price, e.g. `TSh 1,500`.
///
/// Fares are whole shillings -- there are no cents in practice -- so [amount]
/// is an int and no decimal part is ever shown.
String tsh(int amount) => 'TSh ${groupDigits(amount)}';

/// Groups digits in threes, e.g. `1500` becomes `1,500`.
///
/// Handles negatives, though a negative fare should never reach the UI.
String groupDigits(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return negative ? '-$buffer' : buffer.toString();
}
