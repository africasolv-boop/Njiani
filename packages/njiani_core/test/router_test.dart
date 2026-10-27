import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Pumps the real app root for [app] over in-memory stores.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjianiApp app = NjianiApp.rider,
  NjLocale? storedLocale,
  AuthRepository? auth,
  DriverRepository? driver,
  SessionRepository? session,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app),
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
      // Never the real one: it opens a GPS request, and a widget test that
      // reaches a plugin fails in a way that looks like the screen is broken.
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
  group('the gates, in the order a new user meets them', () {
    testWidgets('1. language comes first', (tester) async {
      await pumpApp(tester);
      expect(find.byType(LanguageScreen), findsOneWidget);
    });

    testWidgets('2. then the phone number', (tester) async {
      await pumpApp(tester, storedLocale: NjLocale.en);

      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.byType(PhoneScreen), findsOneWidget);
    });

    testWidgets('3. then the code', (tester) async {
      final container = await pumpApp(tester, storedLocale: NjLocale.en);

      await container.read(authProvider.notifier).sendCode('712345678');
      await tester.pumpAndSettle();

      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('4. then the app', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container =
          await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

      await container.read(authProvider.notifier).sendCode('712345678');
      await tester.pumpAndSettle();
      await container.read(authProvider.notifier).verifyCode(auth.code);
      await tester.pumpAndSettle();

      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    });

    testWidgets('confirming the language does not skip the phone gate',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Endelea · Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(find.byType(PlaceholderScreen), findsNothing);
    });
  });

  group('a signed-in user cannot go back into onboarding', () {
    testWidgets('sign out returns to the phone screen, not the app',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container =
          await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

      await container.read(authProvider.notifier).sendCode('712345678');
      await tester.pumpAndSettle();
      await container.read(authProvider.notifier).verifyCode(auth.code);
      await tester.pumpAndSettle();
      expect(find.byType(PlaceholderScreen), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneScreen), findsOneWidget);
    });

    testWidgets('an already-signed-in session lands straight in the app',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      // Sign in before the first frame, as a returning user would be.
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

      await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

      expect(find.byType(PhoneScreen), findsNothing);
      expect(find.byType(PlaceholderScreen), findsOneWidget);
    });
  });

  group('per-app routing', () {
    testWidgets('the rider app points at the request screen next',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
      await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

      expect(find.textContaining('C8'), findsOneWidget);
    });

    testWidgets('the driver app opens the verification gate, not the app',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
      await pumpApp(tester,
          app: NjianiApp.driver, storedLocale: NjLocale.en, auth: auth);

      // A signed-in driver with no application on file gets sign-up, not the
      // landing screen. Asserted on the screen type rather than on text: the
      // component label on the placeholder moves every time the roadmap does.
      expect(find.byType(DriverSignupScreen), findsOneWidget);
      expect(find.byType(PlaceholderScreen), findsNothing);
    });
  });

  // =========================================================================
  // The third gate: verification. Driver app only.
  // =========================================================================
  group('the driver verification gate', () {
    /// Signs a driver in and pumps the driver app over [row].
    Future<ProviderContainer> pumpDriver(
      WidgetTester tester, {
      Driver? row,
      SessionRepository? session,
    }) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

      final repository = FakeDriverRepository(driver: row);
      addTearDown(repository.dispose);

      return pumpApp(
        tester,
        app: NjianiApp.driver,
        storedLocale: NjLocale.en,
        auth: auth,
        driver: repository,
        session: session,
      );
    }

    /// A session repository that already has the driver online.
    FakeSessionRepository onlineSession() => FakeSessionRepository(
          session: const DriverSession(
            id: 'session-1',
            driverId: 'driver-1',
            routeId: 'route-west',
            destStageId: 'west-9',
            vehicleType: VehicleType.bajaj,
            seatsTotal: 3,
            seatsFree: 3,
            online: true,
          ),
        );

    Driver rowWith(DriverStatus status, {String? reason}) => Driver(
          profileId: 'driver-1',
          vehicleType: VehicleType.bajaj,
          plate: 'T 123 ABC',
          colour: 'Green',
          status: status,
          licencePath: 'driver-1/licence.jpg',
          rejectionReason: reason,
        );

    testWidgets('no application on file opens sign up', (tester) async {
      await pumpDriver(tester);
      expect(find.byType(DriverSignupScreen), findsOneWidget);
    });

    testWidgets('pending holds at the review screen', (tester) async {
      await pumpDriver(tester, row: rowWith(DriverStatus.pending));
      expect(find.byType(DriverPendingScreen), findsOneWidget);
      expect(find.byType(PlaceholderScreen), findsNothing);
    });

    testWidgets('rejected opens the rejection, with the reason',
        (tester) async {
      await pumpDriver(
        tester,
        row: rowWith(DriverStatus.rejected, reason: 'Glare across the number.'),
      );

      expect(find.byType(DriverRejectedScreen), findsOneWidget);
      expect(find.text('Glare across the number.'), findsOneWidget);
    });

    testWidgets('suspended uses the pending screen, in its own words',
        (tester) async {
      await pumpDriver(tester, row: rowWith(DriverStatus.suspended));

      final screen =
          tester.widget<DriverPendingScreen>(find.byType(DriverPendingScreen));
      expect(screen.suspended, isTrue);
      expect(find.text('Your account is on hold'), findsOneWidget);
      expect(find.text("We're checking your documents"), findsNothing);
    });

    testWidgets('approved, but offline, picks a direction first',
        (tester) async {
      // The declaration is the product: a driver who has not said where they
      // are going has nothing to be shown, so they do not reach the feed.
      await pumpDriver(tester, row: rowWith(DriverStatus.approved));

      expect(find.byType(DriverDirectionScreen), findsOneWidget);
      expect(find.byType(PlaceholderScreen), findsNothing);
      expect(find.byType(DriverPendingScreen), findsNothing);
    });

    testWidgets('approved and online lands on the live feed', (tester) async {
      await pumpDriver(
        tester,
        row: rowWith(DriverStatus.approved),
        session: onlineSession(),
      );

      expect(find.byType(DriverFeedScreen), findsOneWidget);
      expect(find.byType(DriverDirectionScreen), findsNothing);
      expect(find.byType(PlaceholderScreen), findsNothing);
    });

    testWidgets('an online driver can still walk back to the picker',
        (tester) async {
      // "already online -> Returning here shows Change, not Go online".
      // The gate must not bounce them straight out again.
      final container = await pumpDriver(
        tester,
        row: rowWith(DriverStatus.approved),
        session: onlineSession(),
      );

      container.read(routerProvider).go(NjRoutes.driverDirection);
      await tester.pumpAndSettle();

      expect(find.byType(DriverDirectionScreen), findsOneWidget);
    });

    // The one the design insists on: a driver who submitted at a stage and
    // closed the app must not have to reinstall to discover they were
    // approved. Nothing is tapped here.
    testWidgets('an approval arrives without the driver doing anything',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

      final repository =
          FakeDriverRepository(driver: rowWith(DriverStatus.pending));
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        app: NjianiApp.driver,
        storedLocale: NjLocale.en,
        auth: auth,
        driver: repository,
      );
      expect(find.byType(DriverPendingScreen), findsOneWidget);

      // An admin approves, somewhere else entirely.
      repository.review(DriverStatus.approved);
      await tester.pumpAndSettle();

      expect(find.byType(DriverPendingScreen), findsNothing);
      // Through the C6 gate and straight on to the C7 one: approved, but
      // with nowhere declared yet.
      expect(find.byType(DriverDirectionScreen), findsOneWidget);
    });

    testWidgets('a rider app never builds the driver gate', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

      final repository =
          FakeDriverRepository(driver: rowWith(DriverStatus.pending));
      addTearDown(repository.dispose);

      final container = await pumpApp(
        tester,
        storedLocale: NjLocale.en,
        auth: auth,
        driver: repository,
      );

      // A passenger with a pending driver row -- which happens, a driver can
      // also be a passenger -- is not held at any gate in this binary, and
      // the binary does not read the table at all.
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(container.exists(driverProvider), isFalse);
    });
  });

  group('localisation survives the auth screens', () {
    testWidgets('a stored English choice reaches the phone screen',
        (tester) async {
      await pumpApp(tester, storedLocale: NjLocale.en);
      expect(find.text('Enter your phone number'), findsOneWidget);
    });

    testWidgets('a stored Kiswahili choice reaches the phone screen',
        (tester) async {
      await pumpApp(tester, storedLocale: NjLocale.sw);
      expect(find.text('Weka namba yako ya simu'), findsOneWidget);
    });

    testWidgets('both languages are supported and no others', (tester) async {
      expect(
        NjStrings.supportedLocales.map((l) => l.languageCode).toSet(),
        {'sw', 'en'},
      );
    });
  });

  group('gallery', () {
    testWidgets('is reachable without signing in first', (tester) async {
      // A development surface: the design system must be checkable without
      // walking the whole sign-in flow every time.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
      await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

      await tester.tap(find.text('Component gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NjGalleryScreen), findsOneWidget);
    });
  });
}
