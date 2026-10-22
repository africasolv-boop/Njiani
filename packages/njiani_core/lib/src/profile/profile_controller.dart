import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../data/supabase_client.dart';
import '../locale/language_controller.dart';
import '../locale/nj_locale.dart';
import 'profile.dart';
import 'profile_repository.dart';

/// How hard to try for a profile row that has not appeared yet.
///
/// Injected so tests can turn the waiting off. A retry that sleeps on a real
/// clock makes every test that touches a profile slower and, worse, leaves a
/// live timer behind when the provider is disposed.
@immutable
class ProfileLoadPolicy {
  const ProfileLoadPolicy({this.attempts = 3, this.delay = const Duration(milliseconds: 350)});

  /// Total attempts, including the first.
  final int attempts;

  /// Wait between attempts. [Duration.zero] skips waiting entirely.
  final Duration delay;

  /// No waiting and no retry, for tests.
  static const ProfileLoadPolicy immediate =
      ProfileLoadPolicy(attempts: 1, delay: Duration.zero);
}

/// The retry policy for loading a profile.
final profileLoadPolicyProvider =
    Provider<ProfileLoadPolicy>((ref) => const ProfileLoadPolicy());

/// Supplies the [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null
      ? FakeProfileRepository()
      : SupabaseProfileRepository(client);
});

/// The signed-in user's profile.
///
/// Null while signed out, and null for the moment between a code being
/// verified and the trigger's row being readable. Screens treat it as
/// "not yet", never as an error.
class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Rebuilds whenever the session appears or disappears.
    final signedIn = ref.watch(authProvider).step == AuthStep.signedIn;
    if (!signedIn) return null;

    // A later language change follows through to the account, so SMS and push
    // keep matching what the user actually reads. Listened to rather than
    // watched: watching would re-load the whole profile on every change.
    ref.listen(languageProvider, (previous, next) {
      if (previous?.locale != next.locale) setLanguage(next.locale);
    });

    _disposed = false;
    ref.onDispose(() => _disposed = true);

    final profile = await _loadWithRetry();
    if (profile != null) await _syncLanguage(profile);
    return profile;
  }

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  bool _disposed = false;

  /// Loads the profile, allowing for the row arriving a moment late.
  ///
  /// `handle_new_user` runs on the auth server, so on a first sign-in the
  /// client can out-race it by a few hundred milliseconds. Retrying twice
  /// turns that race into a non-event; failing would send a brand-new user
  /// back to the phone screen for no reason.
  Future<Profile?> _loadWithRetry() async {
    final policy = ref.read(profileLoadPolicyProvider);

    for (var attempt = 0; attempt < policy.attempts; attempt++) {
      if (_disposed) return null;
      final profile = await _repository.load();
      if (profile != null) return profile;
      if (attempt < policy.attempts - 1 && policy.delay > Duration.zero) {
        await _wait(policy.delay);
      }
    }
    return null;
  }

  /// Waits, but gives the timer up the moment the provider is disposed.
  ///
  /// A plain `Future.delayed` keeps a live timer running after the widget
  /// tree is gone -- harmless in the app, and a hard failure in a widget
  /// test, which is the honest signal that the work had no owner.
  Future<void> _wait(Duration duration) {
    final completer = Completer<void>();
    final timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    ref.onDispose(() {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Mirrors the device's chosen language onto the account.
  ///
  /// The device choice wins. It is made on the very first screen, before
  /// anyone is signed in, so it is the only one that can be right at the
  /// moment it is needed — and the account copy exists so that SMS and push,
  /// which are composed on the server, land in the same language.
  ///
  /// Only written when it actually differs, because this runs on every
  /// sign-in and a no-op round trip is still a round trip on a metered
  /// connection.
  Future<void> _syncLanguage(Profile profile) async {
    final device = ref.read(languageProvider).locale;
    if (profile.lang == device) return;

    try {
      await _repository.setLanguage(device);
      state = AsyncData(profile.copyWith(lang: device));
    } catch (error) {
      // Not fatal. The app is already in the right language; only the
      // server's copy is stale, and the next sign-in will try again.
      debugPrint('[njiani] could not sync profiles.lang: $error');
    }
  }

  /// Changes the account's language, following a change on the device.
  Future<void> setLanguage(NjLocale lang) async {
    final current = state.valueOrNull;
    if (current == null || current.lang == lang) return;

    state = AsyncData(current.copyWith(lang: lang));
    try {
      await _repository.setLanguage(lang);
    } catch (error) {
      debugPrint('[njiani] could not write profiles.lang: $error');
    }
  }

  /// Sets the display name. Used by driver sign-up at C6.
  Future<void> setDisplayName(String name) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.copyWith(displayName: name));
    await _repository.setDisplayName(name);
  }

  /// Re-reads the profile from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repository.load());
  }
}

/// The signed-in user's profile.
final profileProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);
