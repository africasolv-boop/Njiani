import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_driver/main.dart' as app;

/// Pumps the real app root with this binary's identity and in-memory stores.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjLocale? storedLocale,
  AuthRepository? auth,
  DriverRepository? driver,
  SessionRepository? session,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app.njianiApp),
      languageStoreProvider
          .overrideWithValue(InMemoryLanguageStore(storedLocale)),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      profileLoadPolicyProvider
          .overrideWithValue(ProfileLoadPolicy.immediate),
      if (driver != null) driverRepositoryProvider.overrideWithValue(driver),
      if (session != null)
        sessionRepositoryProvider.overrideWithValue(session),
      licenceCameraProvider.overrideWithValue(FakeLicenceCamera()),
      // No polling in tests. A real periodic timer outlives the widget
      // tree and trips `A Timer is still pending`, and a test that means to
      // exercise the nudge would otherwise be able to pass on a poll.
      feedPollPolicyProvider.overrideWithValue(FeedPollPolicy.manual),
      feedAlertProvider.overrideWithValue(FakeFeedAlert()),
      driverLocationProvider.overrideWithValue(FakeDriverLocation()),
      placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
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
  test('this binary is wired to the driver identity', () {
    // Guards against the two apps' main.dart being copy-pasted and left
    // identical. Asserted on the constant rather than by calling runApp.
    expect(app.njianiApp, NjianiApp.driver);
    expect(app.njianiApp.bundleId, 'tz.njiani.driver');
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

    // A signed-in driver with no application on file meets the verification
    // gate, not the app. From C6 this is what the driver binary does
    // differently from the rider binary, so it is asserted on the screen
    // type -- a text match would move with every roadmap label.
    expect(find.byType(DriverSignupScreen), findsOneWidget);
  });

  testWidgets('the component gallery stays reachable', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

    // An approved driver who is NOT online, because from C9 an online
    // driver lands on the feed and the gallery link lives on the direction
    // picker -- in debug builds, which is where a development surface
    // belongs.
    final driver = FakeDriverRepository(
      driver: const Driver(
        profileId: 'driver-1',
        vehicleType: VehicleType.bajaj,
        plate: 'T 123 ABC',
        colour: 'Green',
        status: DriverStatus.approved,
        licencePath: 'driver-1/licence.jpg',
      ),
    );
    addTearDown(driver.dispose);

    await pumpApp(
      tester,
      storedLocale: NjLocale.en,
      auth: auth,
      driver: driver,
      session: FakeSessionRepository(),
    );

    await tester.ensureVisible(find.text('Component gallery'));
    await tester.tap(find.text('Component gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NjGalleryScreen), findsOneWidget);
    expect(
      tester.widget<NjGalleryScreen>(find.byType(NjGalleryScreen)).app,
      NjianiApp.driver,
    );
  });
}
