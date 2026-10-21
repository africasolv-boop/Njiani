/// Why an authentication step did not work.
///
/// A closed set rather than a message string: each one needs different words
/// in two languages, and two of them need a different control on the screen.
enum AuthFailure {
  /// The number did not parse as nine digits.
  invalidPhone,

  /// The code did not match.
  wrongCode,

  /// The code was right once but has timed out.
  expiredCode,

  /// Too many codes requested. Every send costs money, so this is enforced on
  /// the server and simply reported here.
  rateLimited,

  /// No usable connection.
  offline,

  /// The backend is not configured in this build. Shown instead of a silent
  /// failure, so a missing credential is obvious rather than mysterious.
  notConfigured,

  /// Anything else. The message says so plainly rather than inventing a cause.
  unknown,
}
