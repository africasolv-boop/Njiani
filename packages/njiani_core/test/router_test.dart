import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Pumps the real app root for [app] over in-memory stores.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjianiApp app = NjianiApp.rider,
  NjLocale? storedLocale,
  AuthRepository? auth,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app),
      languageStoreProvider
          .overrideWithValue(InMemoryLanguageStore(storedLocale)),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      profileLoadPolicyProvider
          .overrideWithValue(ProfileLoadPolicy.immediate),
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

    testWidgets('the driver app points at driver sign up next',
        (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
      await pumpApp(tester,
          app: NjianiApp.driver, storedLocale: NjLocale.en, auth: auth);

      expect(find.textContaining('C6'), findsOneWidget);
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
