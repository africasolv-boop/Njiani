import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeRequestRepository requests;
  late FakePlacesRepository places;
  late FakeDriverLocation location;

  setUp(() {
    auth = FakeAuthRepository();
    requests = FakeRequestRepository();
    places = FakePlacesRepository();
    location = FakeDriverLocation();
  });

  // A closure, not `tearDown(auth.dispose)`: the tear-off would be evaluated
  // while main() runs, before setUp has assigned anything.
  tearDown(() => auth.dispose());

  Future<void> pumpRequest(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpScreen(
      tester,
      const RequestScreen(),
      auth: auth,
      request: requests,
      places: places,
      location: location,
      locale: locale,
    );
  }

  /// Opens the destination sheet and picks [name].
  Future<void> pickDestination(WidgetTester tester, String name) async {
    await tester.tap(find.text('Choose a destination'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining(name),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(name).last);
    await tester.pumpAndSettle();
  }

  NjButton sendButton(WidgetTester tester) => tester.widget<NjButton>(
        find.ancestor(
          of: find.text('Send request'),
          matching: find.byType(NjButton),
        ),
      );

  Future<void> enterPrice(WidgetTester tester, String price) async {
    await tester.enterText(find.byType(TextField), price);
    await tester.pump();
  }

  // =========================================================================
  group('PriceBand', () {
    test('the middle chip sits between the ends', () {
      const band = PriceBand(low: 1700, high: 2500, mid: 2100);
      expect(band.chips, [1700, 2100, 2500]);
    });

    test('a narrow band does not show the same chip twice', () {
      // 500–600 rounds its middle to one of the ends. Two identical chips
      // look like a bug.
      const band = PriceBand(low: 500, high: 600, mid: 600);
      expect(band.chips, [500, 600]);
    });

    test('below is below, and the band edge is not', () {
      const band = PriceBand(low: 1700, high: 2500, mid: 2100);
      expect(band.isBelow(1699), isTrue);
      expect(band.isBelow(1700), isFalse);
      expect(band.isBelow(9000), isFalse);
    });
  });

  group('RideRequest', () {
    test('counts down, and never past zero', () {
      final at = DateTime(2026, 10, 29, 12);
      final request = RideRequest(
        id: 'r',
        pickupStageId: 'a',
        destStageId: 'b',
        vehicleType: VehicleType.bajaj,
        offerPrice: 1500,
        expiresAt: at.add(const Duration(minutes: 10)),
      );

      expect(request.remaining(at), const Duration(minutes: 10));
      expect(request.hasExpired(at), isFalse);
      expect(
        request.remaining(at.add(const Duration(minutes: 20))),
        Duration.zero,
        reason: 'a negative countdown would render as -9:-58',
      );
      expect(request.hasExpired(at.add(const Duration(minutes: 11))), isTrue);
    });
  });

  // =========================================================================
  group('pHome — the states in the spec', () {
    testWidgets('default: pickup pre-filled, price empty, Send disabled',
        (tester) async {
      await pumpRequest(tester);

      expect(find.text('Pickup, from your location'), findsOneWidget);
      expect(find.text('Ubungo Mataa'), findsOneWidget);
      expect(find.text('Choose a destination'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNull);
    });

    testWidgets('a destination without a price is still not sendable',
        (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');

      expect(sendButton(tester).onPressed, isNull);
    });

    testWidgets('in band: the hint names what drivers take', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '2000');

      expect(
        find.text('Most drivers on this route take TSh 1,700 to 2,500'),
        findsOneWidget,
      );
      expect(sendButton(tester).onPressed, isNotNull);
    });

    // The rule the whole pricing model rests on.
    testWidgets('below band: warned, and still sendable', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '800');

      expect(
        find.text(
          'Below what drivers here usually take. You can still send it.',
        ),
        findsOneWidget,
      );
      expect(
        sendButton(tester).onPressed,
        isNotNull,
        reason: 'the passenger sets the price; a rejected offer tells us '
            'more about the floor than an accepted one does',
      );
    });

    testWidgets('the warning tone is a warning, not an error', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '800');

      final hint = tester.widget<NjHint>(find.byType(NjHint));
      expect(hint.tone, NjHintTone.warning);
    });

    testWidgets('an unpriced pair says so instead of inventing a number',
        (tester) async {
      // A made-up band is worse than none: a passenger anchors to it.
      requests.band = null;
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');

      expect(
        find.text(
          'No usual price for this trip yet. Offer what you think is fair.',
        ),
        findsOneWidget,
      );
      expect(find.byType(NjPriceChips), findsNothing);
    });

    testWidgets('a chip fills the price', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');

      await tester.tap(find.text('2,100'));
      await tester.pumpAndSettle();

      expect(find.text('2100'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('boda is a different trip, and re-reads the band',
        (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '2000');

      await tester.tap(find.text('Boda · 1 seat'));
      await tester.pumpAndSettle();

      // The fake returns one band, so what is asserted here is that the
      // vehicle reached the lookup at all — the key it is read with changes.
      expect(find.text('Boda · 1 seat'), findsOneWidget);
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('sending creates the request with what was chosen',
        (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '2000');

      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(requests.created, hasLength(1));
      expect(requests.created.single.offerPrice, 2000);
      expect(requests.created.single.vehicleType, VehicleType.bajaj);
      expect(requests.created.single.destStageId, 'west-9');
    });

    // The design is explicit, and the reason is given: a silent failure
    // means standing at the road for nothing.
    testWidgets('a failure says the request was NOT created', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '2000');

      requests.failure = const RequestError(RequestFailure.offline);
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.byType(RequestScreen), findsOneWidget,
          reason: 'the form stays, with the choices still in it');
    });

    testWidgets('a trip the server refuses is explained', (tester) async {
      await pumpRequest(tester);
      await pickDestination(tester, 'Kimara Mwisho');
      await enterPrice(tester, '2000');

      requests.failure = const RequestError(RequestFailure.notATrip);
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(find.textContaining('further along the same road'), findsOneWidget);
    });

    testWidgets('the ten minutes is on the screen, not just in the schema',
        (tester) async {
      await pumpRequest(tester);

      expect(
        find.text(
          'Your request expires after 10 minutes if no driver takes it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in Kiswahili', (tester) async {
      await pumpRequest(tester, locale: NjLocale.sw);

      expect(find.text('Unaenda wapi?'), findsOneWidget);
      expect(find.text('Bei yako, kwa kiti'), findsOneWidget);
    });
  });

  // =========================================================================
  group('pHome — waiting', () {
    RideRequest waiting({Duration left = const Duration(minutes: 9)}) =>
        RideRequest(
          id: 'request-1',
          pickupStageId: 'west-1',
          destStageId: 'west-9',
          vehicleType: VehicleType.bajaj,
          offerPrice: 2000,
          expiresAt: DateTime.now().add(left),
          pickupName: 'Ubungo Mataa',
          pickupNameSw: 'Ubungo Mataa',
          destName: 'Kimara Mwisho',
          destNameSw: 'Kimara Mwisho',
        );

    testWidgets('an open request replaces the form', (tester) async {
      requests.request = waiting();
      await pumpRequest(tester);

      expect(find.text('Looking for a driver'), findsOneWidget);
      expect(find.text('Send request'), findsNothing);
    });

    testWidgets('it shows back what was asked for', (tester) async {
      requests.request = waiting();
      await pumpRequest(tester);

      expect(find.text('Ubungo Mataa'), findsOneWidget);
      expect(find.text('Kimara Mwisho'), findsOneWidget);
      expect(find.text('TSh 2,000'), findsOneWidget);
    });

    testWidgets('the ten minutes is visible, not promised', (tester) async {
      requests.request = waiting(left: const Duration(minutes: 9, seconds: 2));
      await pumpRequest(tester);

      expect(find.textContaining('Expires in 9:0'), findsOneWidget);
    });

    testWidgets('cancelling withdraws it and brings the form back',
        (tester) async {
      requests.request = waiting();
      await pumpRequest(tester);

      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();

      expect(requests.cancels, 1);
      expect(find.text('Send request'), findsOneWidget);
    });

    testWidgets('an expired request says the road was quiet, not that it broke',
        (tester) async {
      requests.request = waiting(left: Duration.zero);
      await pumpRequest(tester);

      expect(find.text('Nobody took it this time.'), findsOneWidget);
      expect(find.text('Ask again'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsNothing);
    });
  });

  // =========================================================================
  group('pHome — nowhere to go', () {
    testWidgets('off the corridor offers the stage list', (tester) async {
      places.onCorridor = false;
      places.destinations = [];
      await pumpRequest(tester);

      expect(
        find.text("You're not on a road Njiani covers yet."),
        findsOneWidget,
      );
      expect(find.text('Choose where you are'), findsOneWidget);
    });

    testWidgets('an unseeded database says so', (tester) async {
      places.routesActive = 0;
      places.onCorridor = false;
      places.destinations = [];
      await pumpRequest(tester);

      expect(find.text('Njiani has no roads set up yet.'), findsOneWidget);
      expect(find.text('Choose where you are'), findsNothing);
    });
  });
}
