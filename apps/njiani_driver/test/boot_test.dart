import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_driver/main.dart' as app;

/// Pumps the real app root with this binary's identity and in-memory stores.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjLocale? storedLocale,
  AuthRepository? auth,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app.njianiApp),
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

    expect(find.textContaining('C6'), findsOneWidget);
  });

  testWidgets('the component gallery stays reachable', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpApp(tester, storedLocale: NjLocale.en, auth: auth);

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
