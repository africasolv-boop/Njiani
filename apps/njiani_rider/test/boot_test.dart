import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'package:njiani_rider/main.dart' as app;

void main() {
  testWidgets('boots into the shared component gallery', (tester) async {
    await tester.pumpWidget(const NjGalleryApp(app: app.njianiApp));
    // Not pumpAndSettle: the gallery contains an NjSkeleton, which loops
    // forever by design, so the tree never settles.
    await tester.pump(const Duration(milliseconds: 100));

    // The gallery lives in njiani_core, so finding it proves the workspace
    // dependency resolves and the shared package is really being used.
    expect(find.byType(NjGalleryScreen), findsOneWidget);
  });

  testWidgets('the boot screen stays reachable for credential checks',
      (tester) async {
    await tester.pumpWidget(const NjGalleryApp(app: app.njianiApp));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Build configuration'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text(NjianiApp.rider.bundleId), findsOneWidget);
  });

  test('this binary is wired to the passenger identity', () {
    // Guards against the two apps' main.dart being copy-pasted and left
    // identical. Asserted on the constant rather than by calling runApp:
    // runApp inside a test starts tickers against the real clock, which then
    // trips an assertion when the test clock is advanced.
    expect(app.njianiApp, NjianiApp.rider);
    expect(app.njianiApp.bundleId, 'tz.njiani.rider');
    expect(app.njianiApp.label, NjianiApp.rider.label);
  });

  testWidgets('the gallery is built for this identity', (tester) async {
    await tester.pumpWidget(const NjGalleryApp(app: app.njianiApp));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<NjGalleryScreen>(find.byType(NjGalleryScreen)).app,
      NjianiApp.rider,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      NjianiApp.rider.label,
    );
  });
}
