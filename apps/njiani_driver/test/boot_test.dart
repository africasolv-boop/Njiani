import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_driver/main.dart' as app;

/// Pumps the real app root with this binary's identity and an in-memory store.
Future<void> pumpApp(WidgetTester tester, {NjLocale? stored}) async {
  final container = ProviderContainer(
    overrides: [
      njianiAppProvider.overrideWithValue(app.njianiApp),
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

  testWidgets('a returning user goes straight on', (tester) async {
    await pumpApp(tester, stored: NjLocale.en);

    expect(find.byType(LanguageScreen), findsNothing);
    // This app's own next component, not the other app's.
    expect(find.textContaining('C6'), findsOneWidget);
  });

  testWidgets('the component gallery stays reachable', (tester) async {
    await pumpApp(tester, stored: NjLocale.en);

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
