/// Route paths, in one place so the two apps cannot drift apart.
///
/// Paths are shared even where a screen only exists in one app: a link, a push
/// notification or a deep link should mean the same thing in both binaries.
abstract final class NjRoutes {
  /// The language choice, shown once before authentication.
  static const String language = '/language';

  /// The app's landing route once a language is confirmed.
  ///
  /// A placeholder until C4 brings the phone screen.
  static const String home = '/';

  /// Development-only component gallery. Removed from release builds at C18.
  static const String gallery = '/gallery';
}
