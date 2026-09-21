import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Wraps [child] in the real Njiani theme so tokens resolve as they will
/// in the app.
Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? NjTheme.dark : NjTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('NjButton', () {
    testWidgets('calls onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(NjButton(label: 'Send request', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Send request'));
      expect(taps, 1);
    });

    testWidgets('does nothing when onPressed is null', (tester) async {
      await tester.pumpWidget(
        wrap(const NjButton(label: 'Send code', onPressed: null)),
      );

      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('blocks taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          NjButton(
            label: 'Finding',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Finding'), warnIfMissed: false);
      expect(taps, 0, reason: 'a loading button must not fire again');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('meets the 48pt minimum tap target', (tester) async {
      await tester.pumpWidget(
        wrap(NjButton(label: 'Verify', onPressed: () {})),
      );

      expect(
        tester.getSize(find.byType(NjButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('every variant renders in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        for (final variant in NjButtonVariant.values) {
          await tester.pumpWidget(
            wrap(
              NjButton(
                label: variant.name,
                variant: variant,
                onPressed: () {},
              ),
              brightness: brightness,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('NjSeatIndicator', () {
    testWidgets('draws one block per seat', (tester) async {
      await tester.pumpWidget(
        wrap(const NjSeatIndicator(total: 3, taken: 1)),
      );
      expect(find.byType(AnimatedContainer), findsNWidgets(3));

      await tester.pumpWidget(wrap(const NjSeatIndicator(total: 1, taken: 0)));
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('clamps an over-count instead of overflowing', (tester) async {
      // A seat count above capacity would be a backend bug; the UI should not
      // compound it by drawing a fourth seat in a bajaj.
      await tester.pumpWidget(wrap(const NjSeatIndicator(total: 3, taken: 9)));
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });
  });

  group('NjVehicleType', () {
    test('seat counts match the physical vehicles', () {
      expect(NjVehicleType.bajaj.seats, 3);
      expect(NjVehicleType.boda.seats, 1);
    });

    test('both names are translated', () {
      for (final type in NjVehicleType.values) {
        expect(type.label, isNotEmpty);
        expect(type.labelSw, isNotEmpty);
      }
    });
  });

  group('NjAvatar', () {
    test('derives initials from a name', () {
      expect(NjAvatar.initialsOf('Juma Mwinyi'), 'JM');
      expect(NjAvatar.initialsOf('Neema'), 'N');
      expect(NjAvatar.initialsOf('asha bakari mohamed'), 'AM');
    });

    test('survives messy input rather than throwing', () {
      expect(NjAvatar.initialsOf(''), '?');
      expect(NjAvatar.initialsOf('   '), '?');
      expect(NjAvatar.initialsOf('  Salim   Juma  '), 'SJ');
    });
  });

  group('NjSegmented', () {
    testWidgets('reports the tapped value', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        wrap(
          NjSegmented<String>(
            value: 'bajaj',
            onChanged: (v) => chosen = v,
            segments: const [
              NjSegment(value: 'bajaj', label: 'Bajaj'),
              NjSegment(value: 'boda', label: 'Boda boda'),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Boda boda'));
      expect(chosen, 'boda');
    });
  });

  group('NjPriceChips', () {
    testWidgets('formats prices with thousands separators', (tester) async {
      await tester.pumpWidget(
        wrap(
          NjPriceChips(
            prices: const [1000, 1250, 1500],
            selected: 1250,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('1,000'), findsOneWidget);
      expect(find.text('1,250'), findsOneWidget);
    });

    testWidgets('reports the tapped price', (tester) async {
      int? picked;
      await tester.pumpWidget(
        wrap(
          NjPriceChips(
            prices: const [1000, 1500],
            selected: null,
            onSelected: (p) => picked = p,
          ),
        ),
      );

      await tester.tap(find.text('1,500'));
      expect(picked, 1500);
    });
  });

  group('NjRouteBoard', () {
    testWidgets('shows the route in upper case', (tester) async {
      await tester.pumpWidget(
        wrap(const NjRouteBoard(from: 'Ubungo', to: 'Kimara Korogwe')),
      );
      expect(find.text('UBUNGO TO KIMARA KOROGWE'), findsOneWidget);
    });

    testWidgets('hides the action when no handler is given', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjRouteBoard(
            from: 'Ubungo',
            to: 'Kimara',
            actionLabel: 'Change',
          ),
        ),
      );
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('fires the action when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          NjRouteBoard(
            from: 'Ubungo',
            to: 'Kimara',
            actionLabel: 'Change',
            onAction: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Change'));
      expect(tapped, isTrue);
    });
  });

  group('NjStars', () {
    testWidgets('reports the tapped star', (tester) async {
      int? rated;
      await tester.pumpWidget(
        wrap(NjStars(rating: 0, onRated: (v) => rated = v)),
      );

      await tester.tap(find.byType(Icon).at(3));
      expect(rated, 4);
    });

    testWidgets('is inert without a handler', (tester) async {
      await tester.pumpWidget(wrap(const NjStars(rating: 3)));
      await tester.tap(find.byType(Icon).first);
      expect(tester.takeException(), isNull);
    });
  });

  group('NjOtpField', () {
    testWidgets('advances and reports the completed code', (tester) async {
      String? completed;
      await tester.pumpWidget(
        wrap(
          NjOtpField(
            autofocus: false,
            onCompleted: (code) => completed = code,
          ),
        ),
      );

      final boxes = find.byType(TextField);
      expect(boxes, findsNWidgets(4));

      for (var i = 0; i < 4; i++) {
        await tester.enterText(boxes.at(i), '${i + 1}');
        await tester.pump();
      }

      expect(completed, '1234');
    });

    testWidgets('rejects non-digits', (tester) async {
      await tester.pumpWidget(
        wrap(NjOtpField(autofocus: false, onCompleted: (_) {})),
      );

      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, isEmpty);
    });
  });

  group('NjUploadBox', () {
    testWidgets('switches to the done state', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjUploadBox(
            label: 'Tap to take a photo',
            doneLabel: 'License photo added',
            onTap: _noop,
          ),
        ),
      );
      expect(find.text('Tap to take a photo'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const NjUploadBox(
            label: 'Tap to take a photo',
            doneLabel: 'License photo added',
            state: NjUploadState.done,
            onTap: _noop,
          ),
        ),
      );
      expect(find.text('License photo added'), findsOneWidget);
    });
  });

  group('NjToast', () {
    testWidgets('appears and then removes itself', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NjTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => NjButton(
                label: 'Show',
                onPressed: () => NjToast.show(
                  context,
                  'Neema is yours',
                  duration: const Duration(milliseconds: 300),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Neema is yours'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Neema is yours'), findsNothing);
    });
  });

  group('NjWhereRow', () {
    testWidgets('renders origin only when no destination is given',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjWhereRow(
            fromLabel: 'Starting from your location',
            fromValue: 'Ubungo',
          ),
        ),
      );

      expect(find.text('Ubungo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('prefers toChild over toValue', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjWhereRow(
            fromLabel: 'Pickup',
            fromValue: 'Ubungo',
            toLabel: 'Going to',
            toValue: 'Kimara',
            toChild: Text('picker widget'),
          ),
        ),
      );

      expect(find.text('picker widget'), findsOneWidget);
      expect(find.text('Kimara'), findsNothing);
    });
  });

  group('gallery', () {
    testWidgets('renders every component without overflowing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NjGalleryApp(app: NjianiApp.rider));
      // Not pumpAndSettle: the gallery contains an NjSkeleton, which loops
      // forever by design, so the tree never settles.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NjGalleryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll the whole list; an overflow anywhere throws during layout.
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders both themes in the same view', (tester) async {
      // The design's gallery spec: "Both themes in the same gallery, side by
      // side." A component that works in one and vanishes in the other must
      // be visible here, not discovered inside a flow.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NjGalleryApp(app: NjianiApp.driver));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsWidgets);
    });
  });

  group('NjButton sizes and blocked state', () {
    testWidgets('compact is 48pt, primary is 56pt', (tester) async {
      await tester.pumpWidget(
        wrap(
          NjButton(
            label: 'Pickup',
            size: NjButtonSize.compact,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(NjButton)).height, 48);

      await tester.pumpWidget(
        wrap(NjButton(label: 'Send request', onPressed: () {})),
      );
      expect(tester.getSize(find.byType(NjButton)).height, 56);
    });

    testWidgets('blocked stays at full opacity, unlike disabled',
        (tester) async {
      // "Seats full" is a statement, not a dimmed control. The two must not
      // look the same to a driver glancing at the feed.
      await tester.pumpWidget(
        wrap(
          const NjButton(
            label: 'Seats full',
            variant: NjButtonVariant.blocked,
            onPressed: null,
          ),
        ),
      );
      final blocked = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(NjButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(blocked.opacity, 1.0);

      await tester.pumpWidget(
        wrap(const NjButton(label: 'Send code', onPressed: null)),
      );
      final disabled = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(NjButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(disabled.opacity, 0.45);
    });

    testWidgets('blocked ignores taps even with a handler', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          NjButton(
            label: 'Seats full',
            variant: NjButtonVariant.blocked,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Seats full'), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('NjUploadBox states', () {
    testWidgets('each state shows its own wording', (tester) async {
      const label = 'Tap to photograph your licence';
      const done = 'Licence photo added';

      for (final (state, expected) in const [
        (NjUploadState.empty, label),
        (NjUploadState.done, done),
      ]) {
        await tester.pumpWidget(
          wrap(
            NjUploadBox(
              label: label,
              doneLabel: done,
              state: state,
              onTap: _noop,
            ),
          ),
        );
        expect(find.text(expected), findsOneWidget);
      }
    });

    testWidgets('failed says what was kept, not just what broke',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjUploadBox(
            label: 'Tap to photograph your licence',
            doneLabel: 'Licence photo added',
            state: NjUploadState.failed,
            onTap: _noop,
          ),
        ),
      );
      expect(find.textContaining('Your details are saved'), findsOneWidget);
    });

    testWidgets('uploading blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          NjUploadBox(
            label: 'Tap',
            doneLabel: 'Done',
            state: NjUploadState.uploading,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(NjUploadBox), warnIfMissed: false);
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('NjOtpField error reset', () {
    testWidgets('a wrong code clears the boxes', (tester) async {
      Widget build({required bool hasError}) => wrap(
            NjOtpField(
              autofocus: false,
              hasError: hasError,
              onCompleted: (_) {},
            ),
          );

      await tester.pumpWidget(build(hasError: false));
      final boxes = find.byType(TextField);
      for (var i = 0; i < 4; i++) {
        await tester.enterText(boxes.at(i), '${i + 1}');
        await tester.pump();
      }
      expect(
        tester.widget<TextField>(boxes.first).controller?.text,
        '1',
      );

      // The server rejects the code.
      await tester.pumpWidget(build(hasError: true));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        expect(
          tester.widget<TextField>(boxes.at(i)).controller?.text,
          isEmpty,
          reason: 'box $i should clear so the code can be retyped cleanly',
        );
      }
    });
  });

  group('new components', () {
    testWidgets('NjActionTile exposes its subtitle', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(
          NjActionTile(
            glyph: '!',
            title: 'Report this driver',
            subtitle: 'Price, behaviour, vehicle, or the plate not matching',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Report this driver'), findsOneWidget);
      expect(find.textContaining('plate not matching'), findsOneWidget);
      await tester.tap(find.byType(NjActionTile));
      expect(tapped, isTrue);
    });

    testWidgets('NjActionTile meets the 64pt target', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjActionTile(
            title: 'Call Njiani',
            subtitle: 'A person on the pilot team',
            onTap: _noop,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(NjActionTile)).height,
        greaterThanOrEqualTo(64),
      );
    });

    testWidgets('NjBadge renders every tone', (tester) async {
      for (final tone in NjBadgeTone.values) {
        await tester.pumpWidget(wrap(NjBadge(label: 'V2', tone: tone)));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('NjStatCard shows headline and supporting figures',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjStatCard(
            caption: 'Today · 4 trips',
            value: 'TSh 6,200',
            stats: [
              NjStat(label: 'This week', value: 'TSh 84,500'),
              NjStat(label: 'Seats filled', value: '47 of 63'),
            ],
          ),
        ),
      );
      expect(find.text('TSh 6,200'), findsOneWidget);
      expect(find.text('TSh 84,500'), findsOneWidget);
      expect(find.text('47 of 63'), findsOneWidget);
    });

    testWidgets('NjMeter clamps out-of-range values', (tester) async {
      for (final value in [-1.0, 0.0, 0.5, 1.0, 9.0]) {
        await tester.pumpWidget(wrap(NjMeter(value: value)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'value $value');
      }
    });

    testWidgets('NjSegmentBar draws one block per seat', (tester) async {
      await tester.pumpWidget(wrap(const NjSegmentBar(total: 4, filled: 3)));
      expect(find.byType(Expanded), findsNWidgets(4));
    });

    testWidgets('NjStatusRow shows label and outcome', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NjStatusRow(
            label: 'Licence photo',
            status: 'Rejected',
            tone: NjStatusTone.bad,
          ),
        ),
      );
      expect(find.text('Licence photo'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('NjBanner renders both tones', (tester) async {
      for (final tone in NjBannerTone.values) {
        await tester.pumpWidget(
          wrap(NjBanner(title: 'No connection', message: 'Last known state', tone: tone)),
        );
        expect(find.text('No connection'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('NjSkeletonCard animates without throwing', (tester) async {
      await tester.pumpWidget(wrap(const NjSkeletonCard()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      // Pump past the repeat boundary to catch a disposed-controller tick.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
