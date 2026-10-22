import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

Profile profileWith({NjLocale lang = NjLocale.sw, String? name}) => Profile(
      id: 'user-1',
      phone: TzPhone.tryParse('712345678'),
      lang: lang,
      displayName: name,
    );

void main() {
  group('Profile.fromRow', () {
    test('reads a profiles row', () {
      final profile = Profile.fromRow({
        'id': 'abc',
        'phone': '255712345678',
        'display_name': 'Juma Mwinyi',
        'lang': 'en',
        'created_at': '2026-10-22T08:00:00Z',
      });

      expect(profile.id, 'abc');
      expect(profile.phone?.national, '712345678');
      expect(profile.phone?.formatted, '712 345 678');
      expect(profile.lang, NjLocale.en);
      expect(profile.displayName, 'Juma Mwinyi');
      expect(profile.createdAt?.year, 2026);
    });

    test('an unknown language falls back rather than crashing', () {
      // A row written before a future language is added must still load. A
      // returning user should never be thrown out of the app by a column
      // value their build has not heard of.
      final profile = Profile.fromRow({
        'id': 'abc',
        'phone': '255712345678',
        'lang': 'fr',
      });
      expect(profile.lang, NjLocale.fallback);
    });

    test('tolerates a missing name, date and unparseable phone', () {
      final profile = Profile.fromRow({'id': 'abc', 'phone': null, 'lang': 'sw'});

      expect(profile.phone, isNull);
      expect(profile.displayName, isNull);
      expect(profile.createdAt, isNull);
    });

    test('compares by value', () {
      expect(profileWith(), profileWith());
      expect(profileWith(), isNot(profileWith(lang: NjLocale.en)));
    });
  });

  group('ProfileController', () {
    /// Builds a container with the device language already loaded.
    ///
    /// The load matters: LanguageController only reads the store when asked,
    /// so without it every test would silently run against the default rather
    /// than the language it set up.
    Future<ProviderContainer> containerWith(
      FakeProfileRepository profiles, {
      required FakeAuthRepository auth,
      NjLocale device = NjLocale.sw,
    }) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
          languageStoreProvider.overrideWithValue(InMemoryLanguageStore(device)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(languageProvider.notifier).load();
      return container;
    }

    Future<void> signIn(ProviderContainer container, FakeAuthRepository auth) async {
      await container.read(authProvider.notifier).sendCode('712345678');
      await container.read(authProvider.notifier).verifyCode(auth.code);
    }

    test('is null while signed out', () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await containerWith(FakeProfileRepository(), auth: auth);

      expect(await container.read(profileProvider.future), isNull);
    });

    test('loads the profile once signed in', () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository(profile: profileWith());
      final container = await containerWith(profiles, auth: auth);

      await container.read(profileProvider.future);
      await signIn(container, auth);

      final profile = await container.read(profileProvider.future);
      expect(profile?.id, 'user-1');
      expect(profile?.phone?.national, '712345678');
    });

    test('mirrors the device language onto the account', () async {
      // The device choice is made before anyone is signed in, so it is the
      // only one that can be right when it is needed. The account copy exists
      // so SMS and push, composed on the server, match it.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      // Account says Kiswahili (the default), device says English.
      final profiles = FakeProfileRepository(profile: profileWith());
      final container = await containerWith(profiles, auth: auth, device: NjLocale.en);

      await container.read(profileProvider.future);
      await signIn(container, auth);
      final profile = await container.read(profileProvider.future);

      expect(profiles.languageWrites, [NjLocale.en]);
      expect(profile?.lang, NjLocale.en);
    });

    test('writes nothing when the account already agrees', () async {
      // This runs on every sign-in; a no-op round trip is still a round trip
      // on a metered connection.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository(profile: profileWith(lang: NjLocale.en));
      final container = await containerWith(profiles, auth: auth, device: NjLocale.en);

      await container.read(profileProvider.future);
      await signIn(container, auth);
      await container.read(profileProvider.future);

      expect(profiles.languageWrites, isEmpty);
    });

    test('a failed language sync does not break the session', () async {
      // The app is already in the right language; only the server copy is
      // stale, and the next sign-in tries again.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository(profile: profileWith())
        ..failure = Exception('network');
      final container = await containerWith(profiles, auth: auth, device: NjLocale.en);

      await container.read(profileProvider.future);
      await signIn(container, auth);

      // load() throws too, so the provider surfaces the error rather than
      // pretending — but the auth session is untouched.
      expect(container.read(authProvider).step, AuthStep.signedIn);
    });

    test('retries while the trigger catches up', () async {
      // handle_new_user runs on the auth server, so a first sign-in can
      // out-race it. Failing would send a brand-new user back to the phone
      // screen for no reason.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository(); // no row yet
      final container = await containerWith(profiles, auth: auth);

      await container.read(profileProvider.future);
      await signIn(container, auth);

      // The row appears between attempts.
      profiles.profile = profileWith();
      final profile = await container.read(profileProvider.future);
      expect(profile, isNotNull);
    });

    test('a later language change follows through to the account', () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      // Both start on Kiswahili, the default.
      final profiles = FakeProfileRepository(profile: profileWith());
      final container = await containerWith(profiles, auth: auth);

      await container.read(profileProvider.future);
      await signIn(container, auth);
      await container.read(profileProvider.future);
      expect(profiles.languageWrites, isEmpty);

      container.read(languageProvider.notifier).preview(NjLocale.en);
      await container.read(languageProvider.notifier).confirm();
      await Future<void>.delayed(Duration.zero);

      expect(profiles.languageWrites, [NjLocale.en]);
    });

    test('signing out clears the profile', () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await containerWith(
        FakeProfileRepository(profile: profileWith()),
        auth: auth,
      );

      await container.read(profileProvider.future);
      await signIn(container, auth);
      expect(await container.read(profileProvider.future), isNotNull);

      await container.read(authProvider.notifier).signOut();

      expect(await container.read(profileProvider.future), isNull);
    });

    test('setDisplayName writes through, for driver sign-up at C6', () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository(profile: profileWith());
      final container = await containerWith(profiles, auth: auth);

      await container.read(profileProvider.future);
      await signIn(container, auth);
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).setDisplayName('Juma Mwinyi');

      expect(profiles.nameWrites, ['Juma Mwinyi']);
      expect(
        container.read(profileProvider).valueOrNull?.displayName,
        'Juma Mwinyi',
      );
    });
  });
}
