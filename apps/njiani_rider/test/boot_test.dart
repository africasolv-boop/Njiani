import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_rider/main.dart' as app;

/// Pumps the real app root with this binary's identity and in-memory stores.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjLocale? storedLocale,
  AuthRepository? auth,
  ProfileRepository? profile,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app.njianiApp),
      languageStoreProvider
          .overrideWithValue(InMemoryLanguageStore(storedLocale)),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      profileLoadPolicyProvider
          .overrideWithValue(ProfileLoadPolicy.immediate),
      // In-memory, and never a real one: the request screen reads the stage
      // list and the device's position the moment it builds.
      requestRepositoryProvider.overrideWithValue(FakeRequestRepository()),
      if (profile != null)
        profileRepositoryProvider.overrideWithValue(profile),
      placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
      driverLocationProvider.overrideWithValue(FakeDriverLocation()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(languageProvider.notifier).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NjianiRoot(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('this binary is wired to the passenger identity', () {
    // Guards against the two apps' main.dart being copy-pasted and left
    // identical. Asserted on the constant rather than by calling runApp.
    expect(app.njianiApp, NjianiApp.rider);
    expect(app.njianiApp.bundleId, 'tz.njiani.rider');
  });

  testWidgets('a first run opens the language screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LanguageScreen), findsOneWidget);
  });

  testWidgets('a returning user with no session gets the phone screen',
      (tester) async {
    await pumpApp(tester, storedLocale: NjLocale.en);
    expect(find.byType(PhoneScreen), findsOneWidget);
  });

  testWidgets('signing in reaches this app\'s own next component',
      (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    final container = await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

    await container.read(authProvider.notifier).sendCode('712345678');
    await tester.pumpAndSettle();
    await container.read(authProvider.notifier).verifyCode(auth.code);
    await tester.pumpAndSettle();

    // The rider binary's own next screen. Asserted on the type rather than
    // on a component label, which moves with the roadmap.
    expect(find.byType(RequestScreen), findsOneWidget);
  });

  // Reported as missing from the rider app, and it is the same shared code
  // path the driver app uses: `AuthController` seeds itself from
  // `repository.isSignedIn`, which reads the session `Supabase.initialize()`
  // restored before the first frame. Pinned here because the driver app had
  // this test and the rider app did not, which is the only reason it could
  // have been true in one and not the other.
  testWidgets('a verified number goes straight in, with no code screen',
      (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    // Signed in before the first frame, as a returning user is.
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

    await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

    expect(find.byType(PhoneScreen), findsNothing);
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(RequestScreen), findsOneWidget);
  });

  testWidgets('and a passenger with no name is asked for one first',
      (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

    await pumpApp(
      tester,
      storedLocale: NjLocale.en,
      auth: auth,
      profile: FakeProfileRepository(
        profile: Profile(
          id: 'passenger-1',
          phone: TzPhone.tryParse('712345678'),
          lang: NjLocale.en,
        ),
      ),
    );

    expect(find.byType(PassengerDetailsScreen), findsOneWidget);
    expect(find.byType(RequestScreen), findsNothing);
  });

  testWidgets('a profile that cannot be read does not block the request',
      (tester) async {
    // Being unable to ask for a ride because a nicety could not be read is
    // worse than an unnamed passenger -- and it is the same mistake the
    // driver gate made by resting at the landing screen.
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

    await pumpApp(
      tester,
      storedLocale: NjLocale.en,
      auth: auth,
      profile: FakeProfileRepository()..failure = Exception('offline'),
    );

    expect(find.byType(RequestScreen), findsOneWidget);
    expect(find.byType(PassengerDetailsScreen), findsNothing);
  });

  testWidgets('the component gallery stays reachable', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

    // In NjDevTools now, below the fold: the landing placeholder that used
    // to carry it was replaced by the request screen at C8.
    await tester.ensureVisible(find.text('Component gallery'));
    await tester.tap(find.text('Component gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NjGalleryScreen), findsOneWidget);
    expect(
      tester.widget<NjGalleryScreen>(find.byType(NjGalleryScreen)).app,
      NjianiApp.rider,
    );
  });
}
