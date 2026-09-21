import 'package:shared_preferences/shared_preferences.dart';

import 'nj_locale.dart';

/// Where the chosen language is remembered between launches.
///
/// Per-device, not per-account: the language has to be right on the very first
/// screen, before anyone has signed in. The account's own `profiles.lang`
/// arrives at C5 and is what survives a reinstall.
abstract interface class LanguageStore {
  /// The stored choice, or null if the user has never confirmed one.
  Future<NjLocale?> read();

  /// Remembers [locale] as the confirmed choice.
  Future<void> write(NjLocale locale);
}

/// Backed by `shared_preferences`.
class SharedPrefsLanguageStore implements LanguageStore {
  const SharedPrefsLanguageStore(this._prefs);

  final SharedPreferences _prefs;

  /// Storage key. Changing it would silently re-prompt every existing user.
  static const String key = 'njiani.language';

  @override
  Future<NjLocale?> read() async => NjLocale.tryParse(_prefs.getString(key));

  @override
  Future<void> write(NjLocale locale) async {
    await _prefs.setString(key, locale.code);
  }
}

/// In-memory store, for tests and for the first run of a widget preview.
class InMemoryLanguageStore implements LanguageStore {
  InMemoryLanguageStore([this._value]);

  NjLocale? _value;

  /// Number of writes, so a test can assert the choice was persisted once.
  int writes = 0;

  @override
  Future<NjLocale?> read() async => _value;

  @override
  Future<void> write(NjLocale locale) async {
    _value = locale;
    writes++;
  }
}
