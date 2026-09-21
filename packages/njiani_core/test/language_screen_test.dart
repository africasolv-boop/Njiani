import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Pumps [LanguageScreen] with real localisations and an in-memory store.
Future<InMemoryLanguageStore> pumpLanguage(
  WidgetTester tester, {
  InMemoryLanguageStore? store,
  VoidCallback? onContinue,
}) async {
  final backing = store ?? InMemoryLanguageStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [languageStoreProvider.overrideWithValue(backing)],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: NjTheme.light,
          locale: ref.watch(languageProvider).locale.locale,
          supportedLocales: NjStrings.supportedLocales,
          localizationsDelegates: NjStrings.localizationsDelegates,
          home: LanguageScreen(onContinue: onContinue ?? () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return backing;
}

void main() {
  group('LanguageScreen', () {
    testWidgets('shows the heading in both languages at once', (tester) async {
      // Spec rule: "Both labels appear in both languages on this screen only —
      // the user cannot yet read either reliably."
      await pumpLanguage(tester);

      expect(find.textContaining('Chagua lugha'), findsOneWidget);
      expect(find.textContaining('Choose your language'), findsOneWidget);
    });

    testWidgets('the Continue button is bilingual', (tester) async {
      await pumpLanguage(tester);
      expect(find.text('Endelea · Continue'), findsOneWidget);
    });

    testWidgets('Kiswahili is pre-selected', (tester) async {
      // Spec state: "default — Kiswahili pre-selected."
      await pumpLanguage(tester);

      final tiles = tester.widgetList<NjOptionTile>(find.byType(NjOptionTile));
      final swahili = tiles.firstWhere((t) => t.label == 'Kiswahili');
      final english = tiles.firstWhere((t) => t.label == 'English');

      expect(swahili.selected, isTrue);
      expect(english.selected, isFalse);
    });

    testWidgets('subtitle starts in Kiswahili', (tester) async {
      await pumpLanguage(tester);
      expect(
        find.text('Unaweza kubadilisha hii baadaye kwenye Mipangilio.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping English switches the screen immediately',
        (tester) async {
      // The choice is demonstrated, not described: the localised subtitle
      // changes before anything is confirmed.
      await pumpLanguage(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(
        find.text('You can change this later in Settings.'),
        findsOneWidget,
      );
      final tiles = tester.widgetList<NjOptionTile>(find.byType(NjOptionTile));
      expect(tiles.firstWhere((t) => t.label == 'English').selected, isTrue);
      expect(tiles.firstWhere((t) => t.label == 'Kiswahili').selected, isFalse);
    });

    testWidgets('tapping an option persists nothing until Continue',
        (tester) async {
      final store = await pumpLanguage(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(store.writes, 0);
      expect(await store.read(), isNull);
    });

    testWidgets('Continue persists the tapped choice', (tester) async {
      var continued = false;
      final store = await pumpLanguage(tester, onContinue: () => continued = true);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Endelea · Continue'));
      await tester.pumpAndSettle();

      expect(await store.read(), NjLocale.en);
      expect(continued, isTrue);
    });

    testWidgets('Continue without a pick falls through to Kiswahili',
        (tester) async {
      // Spec state: "no pick — Continue still works."
      var continued = false;
      final store = await pumpLanguage(tester, onContinue: () => continued = true);

      await tester.tap(find.text('Endelea · Continue'));
      await tester.pumpAndSettle();

      expect(await store.read(), NjLocale.sw);
      expect(continued, isTrue);
    });

    testWidgets('endonyms are never translated', (tester) async {
      await pumpLanguage(tester);
      expect(find.text('Kiswahili'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Still their own names after the language changes.
      expect(find.text('Kiswahili'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('lays out on a small handset without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpLanguage(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives the largest clamped text scale', (tester) async {
      // NjianiRoot clamps to 1.3; this screen must still fit at that size.
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageStoreProvider.overrideWithValue(InMemoryLanguageStore()),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: NjTheme.light,
              locale: ref.watch(languageProvider).locale.locale,
              supportedLocales: NjStrings.supportedLocales,
              localizationsDelegates: NjStrings.localizationsDelegates,
              home: MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.3,
                maxScaleFactor: 1.3,
                child: LanguageScreen(onContinue: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('NjOptionTile', () {
    testWidgets('reports taps and marks selection for screen readers',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: NjTheme.light,
          home: Scaffold(
            body: NjOptionTile(
              label: 'Kiswahili',
              note: 'Chaguo la kwanza',
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(NjOptionTile));
      expect(taps, 1);

      final semantics = tester.getSemantics(find.byType(NjOptionTile));
      expect(semantics.label, contains('Kiswahili'));
      expect(semantics.label, contains('Chaguo la kwanza'));
    });

    testWidgets('meets the 56pt option height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NjTheme.light,
          home: Scaffold(
            body: NjOptionTile(
              label: 'English',
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(NjOptionTile)).height,
        greaterThanOrEqualTo(56),
      );
    });
  });
}
