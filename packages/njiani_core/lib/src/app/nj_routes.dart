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
  /// A placeholder until C7 and C8 bring the first real screens.
  static const String home = '/';

  /// Driver sign-up — the verification gate. Driver app only.
  static const String driverSignup = '/driver/signup';

  /// Under review, or suspended.
  static const String driverPending = '/driver/pending';

  /// Rejected, with the one thing to fix.
  static const String driverRejected = '/driver/rejected';

  /// Development-only component gallery. Removed from release builds at C18.
  static const String gallery = '/gallery';

  /// Routes that only make sense before there is a session.
  static const Set<String> onboarding = {language, phone, code};

  /// Routes a driver passes through before they may drive.
  ///
  /// Grouped so the gate can ask "is the driver already on one of these?"
  /// without listing them again, and so an approved driver is moved off all
  /// three by one rule rather than three.
  static const Set<String> driverGate = {
    driverSignup,
    driverPending,
    driverRejected,
  };
}
