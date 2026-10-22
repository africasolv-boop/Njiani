/// Removes anything that looks like a credential from text that will be
/// displayed or logged.
///
/// This exists because a debug line that printed a provider's error message
/// verbatim put a live Postgres password on screen: the project had been
/// configured with a database connection string where the API URL belongs,
/// and the client echoed the whole URI back in its complaint.
///
/// Diagnostics are worth having, but no diagnostic is worth leaking a secret
/// into a screenshot. Anything that might be a credential is replaced rather
/// than shown.
library;

final _userInfoInUri = RegExp(r'(\w+://)([^/\s:@]+):([^/\s@]+)@');
final _jwt = RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+');
final _supabaseKey = RegExp(r'\bsb_(publishable|secret)_[A-Za-z0-9_-]+');
final _whsec = RegExp(r'\bwhsec_[A-Za-z0-9+/=_-]+');
final _bearer = RegExp(r'(?<=[Bb]earer )[A-Za-z0-9._~+/=-]{8,}');

/// Returns [text] with credentials masked.
///
/// Masks, rather than dropping, so the shape of the message survives and it
/// stays possible to see *that* a URI carried a password.
String redactSecrets(String? text) {
  if (text == null || text.isEmpty) return '';
  return text
      .replaceAllMapped(_userInfoInUri, (m) => '${m[1]}${m[2]}:••••••@')
      .replaceAll(_jwt, '«token»')
      .replaceAll(_supabaseKey, '«key»')
      .replaceAll(_whsec, 'whsec_••••••')
      .replaceAllMapped(_bearer, (_) => '«token»');
}
