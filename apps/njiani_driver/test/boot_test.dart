import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_driver/main.dart' as app;

void main() {
  testWidgets('boots into the shared component gallery', (tester) async {
    await tester.pumpWidget(const NjGalleryApp(app: NjianiApp.driver));
    await tester.pumpAndSettle();

    // The gallery lives in njiani_core, so finding it proves the workspace
    // dependency resolves and the shared package is really being used.
    expect(find.byType(NjGalleryScreen), findsOneWidget);
  });

  testWidgets('the boot screen stays reachable for credential checks',
      (tester) async {
    await tester.pumpWidget(const NjGalleryApp(app: NjianiApp.driver));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Build configuration'));
    await tester.pumpAndSettle();

    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text(NjianiApp.driver.bundleId), findsOneWidget);
  });

  testWidgets('main() launches this app, not the other one', (tester) async {
    // Guards against the two mains being copy-pasted and left identical.
    // Asserted on the widget properties rather than on visible text, because
    // 'Njiani Driver' contains 'Njiani' and substring matching cannot tell
    // the two apps apart.
    app.main();
    await tester.pumpAndSettle();

    expect(
      tester.widget<NjGalleryScreen>(find.byType(NjGalleryScreen)).app,
      NjianiApp.driver,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      NjianiApp.driver.label,
    );
  });
}
