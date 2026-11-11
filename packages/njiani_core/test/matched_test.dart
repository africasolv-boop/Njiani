import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSeatRepository seats;

  /// The seat every test below starts from.
  ///
  /// Juma Mwinyi, rated 4.8 over 312 trips, driving a blue bajaj plated
  /// T 482 DKT, 900 m from Ubungo Mataa, at TSh 2,000, with nobody else
  /// aboard. A test names only what it is changing — restating a default
  /// would read as though it mattered, and the analyzer rejects it anyway.
  TripSeat seat({
    SeatState state = SeatState.claimed,
    String name = 'Juma Mwinyi',
    String phone = '+255754000118',
    String plate = 'T 482 DKT',
    String colour = 'Blue',
    VehicleType vehicle = VehicleType.bajaj,
    int price = 2000,
    double? rating = 4.8,
    int trips = 312,
    int seatsTaken = 1,
    double? metres = 900,
    String? pickup = 'Ubungo Mataa',
  }) =>
      TripSeat(
        id: 'seat-1',
        state: state,
        price: price,
        driverName: name,
        driverPhone: phone,
        plate: plate,
        colour: colour,
        vehicleType: vehicle,
        pickupName: pickup,
        pickupNameSw: pickup,
        destName: 'Kimara Mwisho',
        destNameSw: 'Kimara Mwisho',
        rating: rating,
        tripsCount: trips,
        seatsTaken: seatsTaken,
        metresAway: metres,
      );

  setUp(() {
    auth = FakeAuthRepository();
    seats = FakeSeatRepository();
  });

  tearDown(() {
    auth.dispose();
    seats.dispose();
  });

  Future<void> pumpMatched(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpScreen(
      tester,
      const MatchedScreen(),
      auth: auth,
      seat: seats,
      locale: locale,
    );
  }

  // =========================================================================
  group('TripSeat — the ETA', () {
    test('Haversine over 18 km/h, in whole minutes', () {
      // D8. 300 m a minute, so 900 m is three.
      expect(seat().etaMinutes, 3);
      expect(seat(metres: 1500).etaMinutes, 5);
    });

    test('rounds up, never down', () {
      // "Arriving in 1 min" and arriving in 70 seconds is a passenger
      // looking up a second early. The other way round is one who thinks
      // the driver is late.
      expect(seat(metres: 310).etaMinutes, 2);
      expect(seat(metres: 301).etaMinutes, 2);
    });

    test('never zero while there is still road', () {
      expect(seat(metres: 120).etaMinutes, 1);
    });

    test('nothing to divide gives no number at all', () {
      // A driver who has sent no fix. Null is an answer; a guessed minute
      // is not.
      expect(seat(metres: null).etaMinutes, isNull);
      expect(seat(metres: null).hasArrived, isFalse);
    });

    test('inside a stage is arrived, not a countdown', () {
      expect(seat(metres: 40).hasArrived, isTrue);
      expect(seat(metres: 40).etaMinutes, 0);
      expect(seat(metres: 200).hasArrived, isFalse);
    });

    test('aboard is arrived, whatever the distance says', () {
      // A seat cannot be aboard without the vehicle having turned up, and
      // the last position report may be stale.
      expect(seat(state: SeatState.aboard, metres: 4000).hasArrived, isTrue);
    });

    test('an unknown state is not live', () {
      // The conservative direction: "live" is what puts a stranger's phone
      // number on screen, so a state this build does not recognise must
      // never be mistaken for one.
      expect(SeatState.parse('something_new'), SeatState.dropped);
      expect(SeatState.parse('something_new').isLive, isFalse);
      expect(SeatState.parse('claimed').isLive, isTrue);
      expect(SeatState.parse('aboard').isLive, isTrue);
      expect(SeatState.parse('cancelled').isLive, isFalse);
    });

    test('seats taken counts this passenger; sharing does not', () {
      expect(seat().othersAboard, 0);
      expect(seat(seatsTaken: 3).othersAboard, 2);
    });
  });

  // =========================================================================
  group('pMatched — what a passenger at the road reads', () {
    testWidgets('the plate is shown, and larger than the name',
        (tester) async {
      // The trust anchor. A passenger verifies the bajaj that pulls up by
      // reading its plate, and the design is explicit that it outranks the
      // driver's name.
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.text('T 482 DKT'), findsOneWidget);

      final plate = tester.widget<Text>(find.text('T 482 DKT'));
      final name = tester.widget<Text>(find.text('Juma Mwinyi'));
      expect(plate.style!.fontSize, greaterThan(name.style!.fontSize!));
    });

    testWidgets('colour and vehicle, as a word and as the colour',
        (tester) async {
      // Both, because colour exists so a passenger can pick the right bajaj
      // out of four parked together -- and a word only does that for
      // someone who reads the language it is in.
      seats.seat = seat(colour: 'Green');
      await pumpMatched(tester);

      expect(find.text('Green bajaj'), findsOneWidget);
      expect(find.byType(NjColourDot), findsOneWidget);
    });

    testWidgets('the agreed price is on screen', (tester) async {
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.textContaining('TSh 2,000'), findsOneWidget);
      expect(find.textContaining('Price agreed'), findsOneWidget);
    });

    testWidgets('the ETA is minutes, and the stop to wait at',
        (tester) async {
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.text('Arriving in 3 min'), findsOneWidget);
      expect(find.text('Wait at Ubungo Mataa'), findsOneWidget);
    });

    testWidgets('no seconds, ever', (tester) async {
      seats.seat = seat(metres: 120);
      await pumpMatched(tester);

      expect(find.textContaining('sec'), findsNothing);
      expect(find.text('Arriving in 1 min'), findsOneWidget);
    });

    testWidgets('no fix yet says so instead of inventing a number',
        (tester) async {
      seats.seat = seat(metres: null);
      await pumpMatched(tester);

      expect(find.text('Your driver is on the way'), findsOneWidget);
      expect(find.textContaining('Arriving in'), findsNothing);
    });

    testWidgets('arrived names the vehicle, and Cancel is gone',
        (tester) async {
      // Cancel is free *until* the driver arrives. The button disappearing
      // is how the passenger learns that, which is why the design replaces
      // it rather than disabling it.
      seats.seat = seat(metres: 30);
      await pumpMatched(tester);

      expect(find.text('Your bajaj is here'), findsOneWidget);
      expect(find.widgetWithText(NjButton, 'Cancel · no penalty'),
          findsNothing);
    });

    testWidgets('a rating is shown with the trip count', (tester) async {
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.text('4.8 rating · 312 trips'), findsOneWidget);
    });

    testWidgets('an unrated driver is new, not five stars', (tester) async {
      // A made-up 5.0 on a first trip is a lie a passenger acts on.
      seats.seat = seat(rating: null, trips: 0);
      await pumpMatched(tester);

      expect(find.text('New on Njiani'), findsOneWidget);
      expect(find.textContaining('rating'), findsNothing);
    });

    testWidgets('sharing is said out loud', (tester) async {
      // The whole product is a shared seat. Arriving to find two strangers
      // in the bajaj must not be sprung at the kerb.
      seats.seat = seat(seatsTaken: 2);
      await pumpMatched(tester);

      expect(find.text('1 other passenger on board.'), findsOneWidget);
    });

    testWidgets('travelling alone says nothing about sharing',
        (tester) async {
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.textContaining('other passenger'), findsNothing);
    });

    testWidgets('three aboard is plural', (tester) async {
      seats.seat = seat(seatsTaken: 3);
      await pumpMatched(tester);

      expect(find.text('2 other passengers on board.'), findsOneWidget);
    });

    testWidgets('Call names the driver by their first name', (tester) async {
      // "Call Juma Mwinyi" is a form field. "Call Juma" is what the
      // passenger is about to do.
      seats.seat = seat();
      await pumpMatched(tester);

      expect(find.widgetWithText(NjButton, 'Call Juma'), findsOneWidget);
    });

    testWidgets('a driver with no number on file offers no dead button',
        (tester) async {
      seats.seat = seat(phone: '');
      await pumpMatched(tester);

      expect(find.textContaining('Call'), findsNothing);
      expect(find.text('No number for this driver yet'), findsOneWidget);
    });

    testWidgets('the whole screen renders in Kiswahili', (tester) async {
      seats.seat = seat(colour: 'Green', seatsTaken: 2);
      await pumpMatched(tester, locale: NjLocale.sw);

      expect(find.text('Anafika baada ya dakika 3'), findsOneWidget);
      expect(find.text('Subiri Ubungo Mataa'), findsOneWidget);
      expect(find.text('bajaj Kijani'), findsOneWidget);
      expect(find.text('Abiria 1 mwingine yupo ndani.'), findsOneWidget);
      expect(find.widgetWithText(NjButton, 'Mpigie Juma'), findsOneWidget);
      expect(
        find.widgetWithText(NjButton, 'Ghairi · hakuna faini'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  group('pMatched — cancelling', () {
    testWidgets('Cancel says it is free, and asks nothing', (tester) async {
      // No confirm dialog: the cost of a mis-tap is asking again, and a
      // passenger whose plans changed should not have to argue with a modal
      // while a bajaj is on its way.
      seats.seat = seat();
      await pumpMatched(tester);

      // pump, not pumpAndSettle: the button shows a spinner while the write
      // runs, and a spinner never settles.
      await tester.tap(find.widgetWithText(NjButton, 'Cancel · no penalty'));
      await tester.pump();
      await tester.pump();

      expect(seats.cancels, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a failed cancel says so rather than looking cancelled',
        (tester) async {
      seats.seat = seat();
      await pumpMatched(tester);

      seats.failure = const RequestError(RequestFailure.offline);
      await tester.tap(find.widgetWithText(NjButton, 'Cancel · no penalty'));
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't cancel. Try again."), findsOneWidget);
      // Still offering the action, because it did not happen.
      expect(
        find.widgetWithText(NjButton, 'Cancel · no penalty'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });

  // =========================================================================
  group('the seat arriving on its own', () {
    testWidgets('a row change re-reads the seat', (tester) async {
      // The claim happens on another phone. Nothing on the passenger's
      // screen asked for it, so the subscription is the only thing that can
      // bring it.
      seats.seat = seat(metres: 1500);
      await pumpMatched(tester);
      expect(find.text('Arriving in 5 min'), findsOneWidget);

      seats.emit(seat(metres: 600));
      await tester.pumpAndSettle();

      expect(find.text('Arriving in 2 min'), findsOneWidget);
    });

    testWidgets('a poll is what moves the ETA', (tester) async {
      // There is no subscription that could: the driver's position goes to
      // driver_sessions, which a passenger holds no read policy on.
      seats.seat = seat(metres: 1500);
      await pumpMatched(tester);

      seats.seat = seat(metres: 300);
      await seatControllerOf(tester, find.byType(MatchedScreen)).refresh();
      await tester.pumpAndSettle();

      expect(find.text('Arriving in 1 min'), findsOneWidget);
    });

    testWidgets('a failed read keeps the plate on screen', (tester) async {
      // A passenger standing at a stage with a bajaj pulling up needs the
      // plate far more than they need an accurate ETA.
      seats.seat = seat();
      await pumpMatched(tester);

      seats.failure = const RequestError(RequestFailure.offline);
      await seatControllerOf(tester, find.byType(MatchedScreen)).refresh();
      await tester.pumpAndSettle();

      expect(find.text('T 482 DKT'), findsOneWidget);
    });
  });
}
