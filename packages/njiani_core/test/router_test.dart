import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Pumps the real router for [app] over an in-memory store.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  NjianiApp app = NjianiApp.rider,
  NjLocale? stored,
}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app),
      languageStoreProvider.overrideWithValue(InMemoryLanguageStore(stored)),
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
  group('language guard', () {
    testWidgets('a first-run user lands on the language screen',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(LanguageScreen), findsOneWidget);
    });

    testWidgets('a returning user never sees the language screen',
        (tester) async {
      // Spec rule: "never blocks a returning user."
      await pumpApp(tester, stored: NjLocale.en);

      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.byType(PlaceholderScreen), findsOneWidget);
    });

    testWidgets('confirming moves on from the language screen',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(LanguageScreen), findsOneWidget);

      await tester.tap(find.text('Endelea · Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.byType(PlaceholderScreen), findsOneWidget);
    });

    testWidgets('the stored choice is restored on the next launch',
        (tester) async {
      final container = await pumpApp(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Endelea · Continue'));
      await tester.pumpAndSettle();

      final store = container.read(languageStoreProvider);
      expect(await store.read(), NjLocale.en);
    });

    testWidgets('change language returns to the chooser', (tester) async {
      await pumpApp(tester, stored: NjLocale.en);
      expect(find.byType(PlaceholderScreen), findsOneWidget);

      await tester.tap(find.text('Change language'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsOneWidget);
    });
  });

  group('localisation', () {
    testWidgets('a stored Kiswahili choice renders Kiswahili strings',
        (tester) async {
      await pumpApp(tester, stored: NjLocale.sw);
      expect(find.textContaining('Badilisha lugha'), findsOneWidget);
    });

    testWidgets('a stored English choice renders English strings',
        (tester) async {
      await pumpApp(tester, stored: NjLocale.en);
      expect(find.textContaining('Change language'), findsOneWidget);
    });

    testWidgets('both languages are supported and no others', (tester) async {
      expect(
        NjStrings.supportedLocales.map((l) => l.languageCode).toSet(),
        {'sw', 'en'},
      );
    });
  });

  group('per-app routing', () {
    testWidgets('the rider app points at the phone screen next',
        (tester) async {
      await pumpApp(tester, stored: NjLocale.en);
      expect(find.textContaining('C4'), findsOneWidget);
    });

    testWidgets('the driver app points at driver sign up next',
        (tester) async {
      await pumpApp(tester, app: NjianiApp.driver, stored: NjLocale.en);
      expect(find.textContaining('C6'), findsOneWidget);
    });
  });

  group('gallery', () {
    testWidgets('is reachable without walking onboarding first',
        (tester) async {
      // A development surface: the design system must be checkable without
      // first choosing a language every time.
      await pumpApp(tester, stored: NjLocale.en);

      await tester.tap(find.text('Component gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NjGalleryScreen), findsOneWidget);
    });
  });
}
