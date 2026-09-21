import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_rider/main.dart' as app;

void main() {
  testWidgets('boots and renders the shared boot screen', (tester) async {
    await tester.pumpWidget(const NjianiBootApp(app: NjianiApp.rider));

    // The screen comes from njiani_core, so finding it proves the workspace
    // dependency resolves and the shared package is really being used.
    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text(NjianiApp.rider.label), findsOneWidget);
    expect(find.byType(NjianiMark), findsOneWidget);
  });

  testWidgets('lists every configurable credential', (tester) async {
    await tester.pumpWidget(const NjianiBootApp(app: NjianiApp.rider));

    // The list runs past the fold on a phone-sized screen, so scroll to each
    // one: the point is that every credential is reachable, not that they all
    // fit at once.
    for (final entry in AppConfig.entries) {
      final row = find.text(entry.key);
      await tester.scrollUntilVisible(row, 120);
      expect(
        row,
        findsOneWidget,
        reason: '${entry.key} should be reachable on the boot screen',
      );
    }
  });

  testWidgets('main() launches this app, not the other one', (tester) async {
    // Guards against the two mains being copy-pasted and left identical.
    app.main();
    await tester.pumpAndSettle();

    expect(find.text(NjianiApp.rider.label), findsOneWidget);
    expect(find.text(NjianiApp.values.firstWhere((a) => a != NjianiApp.rider).label),
        findsNothing);
  });
}
