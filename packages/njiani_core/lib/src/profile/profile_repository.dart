import 'package:supabase_flutter/supabase_flutter.dart';

import '../locale/nj_locale.dart';
import 'profile.dart';

/// Reading and updating the signed-in user's account record.
abstract interface class ProfileRepository {
  /// The current user's profile, or null if nobody is signed in.
  ///
  /// Returns null rather than throwing when the row is not there yet: the
  /// trigger that creates it runs on the auth server, and a client that
  /// crashes on a one-request race is worse than one that tries again.
  Future<Profile?> load();

  /// Writes the account's language.
  Future<void> setLanguage(NjLocale lang);

  /// Writes the account's display name. Used by driver sign-up at C6.
  Future<void> setDisplayName(String name);
}

/// Backed by the `profiles` table.
class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'profiles';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<Profile?> load() async {
    final id = _userId;
    if (id == null) return null;

    // maybeSingle, not single: a missing row is a state to handle, not an
    // exception to propagate into a screen.
    final row = await _client
        .from(_table)
        .select('id, phone, display_name, lang, created_at')
        .eq('id', id)
        .maybeSingle();

    return row == null ? null : Profile.fromRow(row);
  }

  @override
  Future<void> setLanguage(NjLocale lang) async {
    final id = _userId;
    if (id == null) return;
    await _client.from(_table).update({'lang': lang.code}).eq('id', id);
  }

  @override
  Future<void> setDisplayName(String name) async {
    final id = _userId;
    if (id == null) return;
    await _client.from(_table).update({'display_name': name}).eq('id', id);
  }
}

/// In-memory profile store, for tests and for running without a backend.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});

  /// The profile [load] returns. Null models an account whose row has not
  /// appeared yet.
  Profile? profile;

  /// Languages written, in order, so a test can assert the sync happened once.
  final List<NjLocale> languageWrites = [];

  /// Names written, in order.
  final List<String> nameWrites = [];

  /// Forced failure, for exercising the error path.
  Object? failure;

  @override
  Future<Profile?> load() async {
    if (failure != null) throw failure!;
    return profile;
  }

  @override
  Future<void> setLanguage(NjLocale lang) async {
    if (failure != null) throw failure!;
    languageWrites.add(lang);
    profile = profile?.copyWith(lang: lang);
  }

  @override
  Future<void> setDisplayName(String name) async {
    if (failure != null) throw failure!;
    nameWrites.add(name);
    profile = profile?.copyWith(displayName: name);
  }
}
