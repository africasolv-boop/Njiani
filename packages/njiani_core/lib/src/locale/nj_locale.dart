import 'dart:ui' show Locale;

/// The languages Njiani ships in.
///
/// Declaration order is preference order: Kiswahili first, because it is the
/// first language of the pilot corridor. Every user-facing string exists in
/// both -- there are no English-only screens.
enum NjLocale {
  /// Kiswahili. The default.
  sw(code: 'sw', endonym: 'Kiswahili'),

  /// English.
  en(code: 'en', endonym: 'English');

  const NjLocale({required this.code, required this.endonym});

  /// ISO 639-1 code, matching the `.arb` file suffix.
  final String code;

  /// The language's name in its own language. Never translated.
  final String endonym;

  /// The default when nothing has been chosen.
  static const NjLocale fallback = NjLocale.sw;

  /// A Flutter [Locale] for [MaterialApp.locale].
  Locale get locale => Locale(code);

  /// Parses a stored or platform code, falling back to [fallback].
  ///
  /// Accepts a full tag such as `sw_TZ` or `en-GB` by reading only the
  /// language subtag -- a device set to Tanzanian English should get English,
  /// not the fallback.
  static NjLocale? tryParse(String? code) {
    if (code == null || code.isEmpty) return null;
    final language = code.split(RegExp('[-_]')).first.toLowerCase();
    for (final value in NjLocale.values) {
      if (value.code == language) return value;
    }
    return null;
  }
}
