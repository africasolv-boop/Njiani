import 'package:flutter/foundation.dart';

/// Why an authentication step did not work.
///
/// A closed set rather than a message string: each one needs different words
/// in two languages, and several need a different control on the screen.
enum AuthFailure {
  /// The number did not parse as nine digits.
  ///
  /// Only ever set by **our own** parsing, never inferred from a server
  /// message. The client validates the number before sending, so by the time
  /// the backend is involved the digits are not the problem -- and telling
  /// someone to fix a number that is already correct sends them in circles.
  invalidPhone,

  /// The code did not match.
  wrongCode,

  /// The code was right once but has timed out.
  expiredCode,

  /// Too many codes requested. Every send costs money, so this is enforced on
  /// the server and simply reported here.
  rateLimited,

  /// Phone sign-in is not switched on, or the SMS hook is not wired up.
  ///
  /// A configuration problem on the project, not anything the user did. It
  /// has its own value because the fix is in the Supabase dashboard and the
  /// message has to say so.
  providerDisabled,

  /// No usable connection.
  offline,

  /// The backend is not configured in this build. Shown instead of a silent
  /// failure, so a missing credential is obvious rather than mysterious.
  notConfigured,

  /// Anything else. The message says so plainly rather than inventing a cause,
  /// and [AuthError.detail] carries what the server actually said.
  unknown,
}

/// A failure, plus whatever the provider actually said about it.
///
/// The raw message is kept because a classifier that throws it away is a
/// classifier you cannot debug: a backend misconfiguration once surfaced as
/// "Enter 9 digits, without the leading zero", which sent the user to edit a
/// number that was already correct. [detail] is shown on screen in debug
/// builds and logged in every build, so the next surprise is one screenshot
/// away from being understood.
@immutable
class AuthError {
  const AuthError(this.kind, {this.detail});

  /// What kind of failure this is.
  final AuthFailure kind;

  /// The provider's own words, when there were any.
  final String? detail;

  /// Whether this is worth showing a developer on screen.
  bool get hasDetail => detail != null && detail!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is AuthError && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => 'AuthError($kind${hasDetail ? ': $detail' : ''})';
}
