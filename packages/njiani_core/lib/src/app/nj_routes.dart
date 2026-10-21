/// Route paths, in one place so the two apps cannot drift apart.
///
/// Paths are shared even where a screen only exists in one app: a link, a push
/// notification or a deep link should mean the same thing in both binaries.
abstract final class NjRoutes {
  /// The language choice, shown once before authentication.
  static const String language = '/language';

  /// Phone number entry.
  static const String phone = '/phone';

  /// SMS code entry.
  static const String code = '/code';

  /// The app's landing route once signed in.
  ///
  /// A placeholder until C6 and C8 bring the first real screens.
  static const String home = '/';

  /// Development-only component gallery. Removed from release builds at C18.
  static const String gallery = '/gallery';

  /// Routes that only make sense before there is a session.
  static const Set<String> onboarding = {language, phone, code};
}
