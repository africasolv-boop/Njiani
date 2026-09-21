import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  for (final app in NjianiApp.values) {
    group(app.label, () {
      testWidgets('renders its own identity', (tester) async {
        await tester.pumpWidget(NjianiBootApp(app: app));

        expect(find.text(app.label), findsOneWidget);
        expect(find.text(app.tagline), findsOneWidget);
        expect(find.text(app.taglineSw), findsOneWidget);
        expect(find.text(app.bundleId), findsOneWidget);
      });

      testWidgets('renders in dark mode without overflowing', (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(platformBrightness: Brightness.dark),
            child: NjianiBootApp(app: app),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BootScreen), findsOneWidget);
      });

      testWidgets('renders on a small screen without overflowing',
          (tester) async {
        // Many drivers are on small, low-end Android handsets.
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(NjianiBootApp(app: app));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('NjianiMark paints at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NjianiMark(size: 96))),
    );

    expect(tester.getSize(find.byType(NjianiMark)), const Size(96, 96));
  });
}
