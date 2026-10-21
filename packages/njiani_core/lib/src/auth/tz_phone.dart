/// A Tanzanian mobile number, normalised.
///
/// Users write the same number four different ways -- `0712 345 678`,
/// `712345678`, `+255 712 345 678`, `255712345678` -- and all of them mean one
/// person. This class is the single place that decides they are equal, so no
/// screen, no repository and no migration has to guess.
///
/// The national significant number is nine digits. A leading zero is a local
/// writing convention, not part of the number, so it is stripped: the design
/// is explicit that `0712…` and `712…` are the same.
class TzPhone {
  const TzPhone._(this.national);

  /// The nine-digit national significant number, e.g. `712345678`.
  final String national;

  /// Tanzania's country calling code.
  static const String countryCode = '255';

  /// Length of a national significant number.
  static const int nationalLength = 9;

  /// Parses any of the forms above, or returns null.
  ///
  /// Deliberately does not check the operator prefix. Restricting to the
  /// prefixes in use today would reject a real customer the moment a new
  /// range is issued, and a wrong number simply never receives its code --
  /// which the user discovers in seconds. The design's rule is nine digits.
  static TzPhone? tryParse(String? input) {
    if (input == null) return null;

    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Strip the country code, however it was written.
    if (digits.startsWith(countryCode) &&
        digits.length == countryCode.length + nationalLength) {
      digits = digits.substring(countryCode.length);
    }

    // Strip the local leading zero.
    if (digits.length == nationalLength + 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != nationalLength) return null;
    // A number cannot begin with 0 once normalised.
    if (digits.startsWith('0')) return null;

    return TzPhone._(digits);
  }

  /// Whether [input] would parse. Cheaper to read at a call site than
  /// `tryParse(x) != null`.
  static bool isValid(String? input) => tryParse(input) != null;

  /// How many digits [input] contributes, for the "enabled at nine" rule.
  ///
  /// Counts what the number will be after normalising, so typing the leading
  /// zero does not make the field look one digit further along than it is.
  static int digitCount(String? input) {
    if (input == null) return 0;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(countryCode) &&
        digits.length > countryCode.length) {
      digits = digits.substring(countryCode.length);
    }
    if (digits.length > 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits.length;
  }

  /// E.164, for Supabase Auth: `+255712345678`.
  String get e164 => '+$countryCode$national';

  /// Digits only, for `profiles.phone`: `255712345678`.
  ///
  /// Matches the column's check constraint, `^255[0-9]{9}$`.
  String get stored => '$countryCode$national';

  /// Grouped for display: `712 345 678`.
  String get formatted =>
      '${national.substring(0, 3)} ${national.substring(3, 6)} '
      '${national.substring(6)}';

  /// Partly hidden, for a screen someone else can see: `712 ••• 678`.
  String get masked =>
      '${national.substring(0, 3)} ••• ${national.substring(6)}';

  @override
  bool operator ==(Object other) =>
      other is TzPhone && other.national == national;

  @override
  int get hashCode => national.hashCode;

  @override
  String toString() => e164;
}
