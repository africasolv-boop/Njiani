import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeDriverRepository drivers;
  late FakeSessionRepository sessions;
  late FakeFeedRepository feed;
  late FakeFeedAlert alert;

  const approved = Driver(
    profileId: 'driver-1',
    vehicleType: VehicleType.bajaj,
    plate: 'T 123 ABC',
    colour: 'Green',
    status: DriverStatus.approved,
    licencePath: 'driver-1/licence.jpg',
  );

  DriverSession online({int seatsFree = 3}) => DriverSession(
        id: 'session-1',
        driverId: 'driver-1',
        routeId: 'route-west',
        destStageId: 'west-9',
        vehicleType: VehicleType.bajaj,
        seatsTotal: 3,
        seatsFree: seatsFree,
        online: true,
        destName: 'Kimara Mwisho',
        destNameSw: 'Kimara Mwisho',
        fromName: 'Ubungo Mataa',
        fromNameSw: 'Ubungo Mataa',
      );

  /// `from`, `price` and `metres` are required on purpose: every assertion
  /// below is about one of them, and a default would let a test read as
  /// though it did not care about the value it is checking.
  FeedRequest request({
    required String from,
    required int price,
    required int metres,
    String id = 'r1',
    String to = 'Kimara Mwisho',
  }) =>
      FeedRequest(
        id: id,
        pickupStage: from,
        pickupStageSw: from,
        destStage: to,
        destStageSw: to,
        offerPrice: price,
        metresAhead: metres,
      );

  setUp(() {
    auth = FakeAuthRepository();
    drivers = FakeDriverRepository(driver: approved);
    sessions = FakeSessionRepository(session: online());
    feed = FakeFeedRepository();
    alert = FakeFeedAlert();
  });

  tearDown(() {
    auth.dispose();
    drivers.dispose();
    feed.dispose();
  });

  Future<void> pumpFeed(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpScreen(
      tester,
      const DriverFeedScreen(),
      auth: auth,
      driver: drivers,
      session: sessions,
      feed: feed,
      alert: alert,
      locale: locale,
    );
  }

  FeedController controller(WidgetTester tester) =>
      feedControllerOf(tester, find.byType(DriverFeedScreen));

  // =========================================================================
  group('the topic the client listens on', () {
    test('matches route_feed_topic() in SQL', () {
      // A mismatch here is a feed that is silently never live. The SQL side
      // has an assertion pinning the same format.
      expect(
        SupabaseFeedRepository.topicFor(
          routeId: '11111111-1111-4111-8111-111111111111',
          vehicle: VehicleType.bajaj,
        ),
        'feed:11111111-1111-4111-8111-111111111111:bajaj',
      );
      expect(
        SupabaseFeedRepository.topicFor(
          routeId: 'r',
          vehicle: VehicleType.boda,
        ),
        'feed:r:boda',
      );
    });
  });

  group('FeedRequest', () {
    test('reads a row of match_requests_for_session()', () {
      final parsed = FeedRequest.fromRow(const {
        'request_id': 'r1',
        'pickup_stage': 'Shekilango',
        'pickup_stage_sw': 'Shekilango',
        'dest_stage': 'Kimara Mwisho',
        'dest_stage_sw': 'Kimara Mwisho',
        'offer_price': 1500,
        'meters_ahead': 880,
        'created_at': '2026-10-28T08:00:00Z',
      });

      expect(parsed.id, 'r1');
      expect(parsed.offerPrice, 1500);
      expect(parsed.metresAhead, 880);
    });
  });

  // =========================================================================
  group('dFeed — the states in the spec', () {
    testWidgets('empty: named, and promises the sound', (tester) async {
      await pumpFeed(tester);

      // The promise has to be kept, or a driver decides the app is broken
      // and stops looking at it.
      expect(
        find.text(
          "Nobody heading to Kimara Mwisho yet. You'll hear a sound when a "
          'request comes in.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the route board names where they are and where they said',
        (tester) async {
      await pumpFeed(tester);

      final board = tester.widget<NjRouteBoard>(find.byType(NjRouteBoard));
      expect(board.from, 'Ubungo Mataa');
      expect(board.to, 'Kimara Mwisho');
      expect(find.text("You're online"), findsOneWidget);
    });

    testWidgets('a request shows its pickup, distance, price and destination',
        (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      expect(find.text('Shekilango · 880 m ahead'), findsOneWidget);
      expect(find.text('TSh 1,500'), findsOneWidget);
      expect(find.text('To Kimara Mwisho'), findsOneWidget);
    });

    testWidgets('a long way off is shown in kilometres', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 3776)];
      await pumpFeed(tester);

      // "3776 m" is not something a driver can picture.
      expect(find.text('Shekilango · 3.8 km ahead'), findsOneWidget);
    });

    // THE ORDER IS THE PRODUCT. The server returns nearest-ahead first and
    // the screen must not re-sort -- least of all by price.
    testWidgets('the server order is kept, nearest first and never by price',
        (tester) async {
      feed.requests = [
        request(id: 'near', from: 'Shekilango', price: 1200, metres: 880),
        request(id: 'far', from: 'Kibo', price: 5000, metres: 3776),
      ];
      await pumpFeed(tester);

      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      expect(
        shown.indexWhere((s) => s.startsWith('Shekilango')),
        lessThan(shown.indexWhere((s) => s.startsWith('Kibo'))),
        reason: 'the better offer is further away, and must stay further '
            'down the list',
      );
    });

    testWidgets('seats full says so', (tester) async {
      sessions.session = online(seatsFree: 0);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      expect(find.text('Every seat taken'), findsOneWidget);
      expect(find.text('2 of 3 seats free'), findsNothing);
    });

    testWidgets('seats free are counted', (tester) async {
      sessions.session = online(seatsFree: 2);
      await pumpFeed(tester);

      expect(find.text('2 of 3 seats free'), findsOneWidget);
      final seats = tester.widget<NjSeatIndicator>(
        find.byType(NjSeatIndicator),
      );
      expect(seats.total, 3);
      expect(seats.taken, 1);
    });

    testWidgets('Pickup is live, and claims the seat', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      final button = tester.widget<NjButton>(
        find.widgetWithText(NjButton, 'Pickup'),
      );
      expect(button.onPressed, isNotNull);
      // The moment of commitment, which the design reserves bajaj yellow
      // for. Not the same colour as a routine tap.
      expect(button.variant, NjButtonVariant.bajaj);
    });

    testWidgets('renders in Kiswahili', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester, locale: NjLocale.sw);

      expect(find.textContaining('Moja kwa moja'), findsOneWidget);
      expect(find.text('Hadi Kimara Mwisho'), findsOneWidget);
    });
  });

  // =========================================================================
  group('dFeed — staying live', () {
    testWidgets('it listens on its own route and vehicle, not everything',
        (tester) async {
      await pumpFeed(tester);

      expect(feed.topics, ['feed:route-west:bajaj']);
    });

    testWidgets('a nudge re-reads the feed', (tester) async {
      await pumpFeed(tester);
      final before = feed.reads;

      // A passenger sends a request somewhere else entirely.
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      feed.nudge();
      await tester.pumpAndSettle();

      expect(feed.reads, greaterThan(before));
      expect(find.text('To Kimara Mwisho'), findsOneWidget);
    });

    testWidgets('the answer always comes from the session, not the nudge',
        (tester) async {
      // The nudge is a doorbell, not a window. A driver has no read policy
      // on ride_requests, so the payload cannot be the data -- and the only
      // thing the feed is ever read by is the driver's own session id, which
      // is what scopes `match_requests_for_session`. If a request id or a
      // route ever showed up here, the nudge would have become a window.
      //
      // `Stream<void>` makes it impossible by construction; this pins the
      // other half, that nothing else is used to fetch.
      await pumpFeed(tester);
      feed.nudge();
      await tester.pumpAndSettle();

      expect(feed.readFor, isNotEmpty);
      expect(feed.readFor, everyElement('session-1'));
    });

    testWidgets('a new arrival sounds once, however many arrive',
        (tester) async {
      await pumpFeed(tester);
      expect(alert.fired, 0, reason: 'nothing has arrived yet');

      feed.requests = [
        for (final id in ['a', 'b', 'c'])
          request(id: id, from: 'Shekilango', price: 1500, metres: 880),
      ];
      feed.nudge();
      await tester.pumpAndSettle();

      expect(
        alert.fired,
        1,
        reason: 'three arriving together is one event to a driver; three '
            'chimes in a second is a malfunction',
      );
    });

    testWidgets('the first load is silent', (tester) async {
      // Everything already waiting is "new" on the first read, and a chime
      // for each would fire at exactly the moment the driver is reading them.
      feed.requests = [
        for (final id in ['a', 'b'])
          request(id: id, from: 'Shekilango', price: 1500, metres: 880),
      ];
      await pumpFeed(tester);

      expect(alert.fired, 0);
    });

    testWidgets('a re-read with nothing new is silent', (tester) async {
      feed.requests = [
        request(id: 'a', from: 'Shekilango', price: 1500, metres: 880),
      ];
      await pumpFeed(tester);

      feed.nudge();
      await tester.pumpAndSettle();

      expect(alert.fired, 0);
    });

    testWidgets('a request leaving the feed is silent', (tester) async {
      feed.requests = [
        request(id: 'a', from: 'Shekilango', price: 1500, metres: 880),
      ];
      await pumpFeed(tester);

      feed.requests = [];
      feed.nudge();
      await tester.pumpAndSettle();

      expect(alert.fired, 0);
      expect(find.textContaining('Nobody heading to'), findsOneWidget);
    });
  });

  // =========================================================================
  group('dFeed — when the connection goes', () {
    testWidgets('the list is kept and labelled, not blanked', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);
      expect(find.text('To Kimara Mwisho'), findsOneWidget);

      // Into a tunnel.
      feed.failure = const DriverError(DriverFailure.offline);
      await controller(tester).refresh();
      await tester.pumpAndSettle();

      // The previous answer is still the best one available...
      expect(find.text('To Kimara Mwisho'), findsOneWidget);
      // ...but it is no longer a claim about now.
      expect(find.textContaining('No connection'), findsOneWidget);
    });

    testWidgets('recovering clears the banner', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      feed.failure = const DriverError(DriverFailure.offline);
      await controller(tester).refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('No connection'), findsOneWidget);

      feed.failure = null;
      await controller(tester).refresh();
      await tester.pumpAndSettle();

      expect(find.textContaining('No connection'), findsNothing);
    });

    testWidgets('a failed first read shows no stale time', (tester) async {
      // Nothing was ever read, so there is no "as of" to show. The banner
      // would otherwise claim a time it does not have.
      feed.failure = const DriverError(DriverFailure.offline);
      await pumpFeed(tester);

      expect(find.textContaining('No connection'), findsNothing);
    });
  });

  // =========================================================================
  group('FeedState', () {
    test('empty is empty', () {
      expect(const FeedState().isEmpty, isTrue);
      expect(const FeedState().stale, isFalse);
    });

    test('copyWith keeps what it is not given', () {
      final at = DateTime(2026, 10, 28, 14, 2);
      final state = FeedState(readAt: at, requests: [
        const FeedRequest(
          id: 'r',
          pickupStage: 'a',
          pickupStageSw: 'a',
          destStage: 'b',
          destStageSw: 'b',
          offerPrice: 1,
          metresAhead: 1,
        ),
      ]);

      final stale = state.copyWith(stale: true);
      expect(stale.readAt, at);
      expect(stale.requests, hasLength(1));
      expect(stale.stale, isTrue);
    });
  });

  // =========================================================================
  group('the claim', () {
    /// Runs out the timers a claim leaves behind.
    ///
    /// Both are `Future.delayed`, which `pumpAndSettle` does not advance: the
    /// two-second band on a lost card, and the toast that says what happened.
    /// Three rounds, because the won path chains one after the other.
    Future<void> drain(WidgetTester tester) async {
      for (var round = 0; round < 3; round++) {
        await tester.pump(const Duration(seconds: 3));
      }
    }

    testWidgets('one tap takes the seat, with no confirm dialog',
        (tester) async {
      // No dialog on purpose: the driver is in traffic, and the design says
      // so. The undo is Cancel on the other side, not a question at 40 km/h.
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pumpAndSettle();

      expect(feed.claimed, ['r1']);
      expect(find.byType(AlertDialog), findsNothing);
      await drain(tester);
    });

    testWidgets('a won claim names the stop, and the card leaves',
        (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pumpAndSettle();

      // The toast is the only thing that says what just happened: the card
      // has gone, and a driver watching a card vanish learns nothing.
      expect(
        find.textContaining('the passenger is at Shekilango'),
        findsOneWidget,
      );
      expect(find.text('Shekilango · 880 m ahead'), findsNothing);
      await drain(tester);
    });

    testWidgets('a lost claim shows the band, then the card leaves',
        (tester) async {
      feed.claimResult = const ClaimResult(ClaimOutcome.alreadyTaken);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      // Mid-linger. Not settled yet, so the band is up and the card is
      // still there.
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Taken by another driver'), findsOneWidget);
      expect(find.text('Shekilango · 880 m ahead'), findsOneWidget);
      // And nothing left to tap on a card nobody can take.
      expect(find.widgetWithText(NjButton, 'Pickup'), findsNothing);

      await drain(tester);
      expect(find.text('Taken by another driver'), findsNothing);
      expect(find.text('Shekilango · 880 m ahead'), findsNothing);
    });

    testWidgets('a lost card survives a nudge arriving mid-band',
        (tester) async {
      // The window is two seconds wide and a nudge inside it is ordinary.
      // Yanking the card out would leave the driver never knowing.
      feed.claimResult = const ClaimResult(ClaimOutcome.alreadyTaken);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pump(const Duration(milliseconds: 300));

      // The server has already dropped it: it is claimed, by someone else.
      feed.requests = [];
      await controller(tester).refresh();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Taken by another driver'), findsOneWidget);

      await drain(tester);
      expect(find.text('Taken by another driver'), findsNothing);
    });

    testWidgets('no toast on a lost claim — the band already said it',
        (tester) async {
      feed.claimResult = const ClaimResult(ClaimOutcome.alreadyTaken);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Try again'), findsNothing);
      expect(find.text('Taken by another driver'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('a full vehicle offers no Pickup, and says why',
        (tester) async {
      sessions.session = online(seatsFree: 0);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      // Filled flat and labelled, not a dimmed Pickup. The design asks for
      // both and they mean different things: "not yet" against "not
      // possible, and here is why".
      final button = tester.widget<NjButton>(
        find.widgetWithText(NjButton, 'Seats full'),
      );
      expect(button.onPressed, isNull);
      expect(button.variant, NjButtonVariant.blocked);
      expect(find.widgetWithText(NjButton, 'Pickup'), findsNothing);
      expect(find.text('Every seat taken'), findsOneWidget);
    });

    testWidgets('filling the last seat turns every other Pickup off',
        (tester) async {
      // The state the design names: "Every Pickup becomes a disabled 'Seats
      // full'". Read off the session, which the claim re-reads, so it is
      // still right after a rebuild.
      sessions.session = online(seatsFree: 1);
      feed.requests = [
        request(from: 'Shekilango', price: 1500, metres: 880),
        request(from: 'Ubungo Mataa', price: 1800, metres: 1200, id: 'r2'),
      ];
      await pumpFeed(tester);
      expect(find.widgetWithText(NjButton, 'Pickup'), findsNWidgets(2));

      // What the server does when the seat is taken.
      feed.onClaim = () => sessions.session = online(seatsFree: 0);
      await tester.tap(find.widgetWithText(NjButton, 'Pickup').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(NjButton, 'Pickup'), findsNothing);
      expect(find.widgetWithText(NjButton, 'Seats full'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('seats_full from the server does not claim anything',
        (tester) async {
      // Our count said there was room and the server disagreed. The vehicle
      // filling up underneath the driver is exactly this case.
      feed.claimResult = const ClaimResult(ClaimOutcome.seatsFull);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      feed.onClaim = () => sessions.session = online(seatsFree: 0);
      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pumpAndSettle();

      // Still on the feed: nobody else has taken it, there is simply
      // nowhere to put them.
      expect(find.text('Shekilango · 880 m ahead'), findsOneWidget);
      expect(find.widgetWithText(NjButton, 'Seats full'), findsOneWidget);
    });

    testWidgets('a second tap mid-claim is the driver asking louder',
        (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      feed.claimGate = Completer<void>();
      final pending = controller(tester).claim(feed.requests.first);
      await tester.pump();

      // Held, not queued. Two claims a few hundred milliseconds apart in a
      // one-seat vehicle would both go through, and one of them would come
      // back seats_full after the passenger was told they had a ride.
      expect(
        tester
            .widget<NjButton>(find.widgetWithText(NjButton, 'Claiming…'))
            .onPressed,
        isNull,
      );

      feed.claimGate!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(feed.claimed, ['r1']);
    });

    testWidgets('every other Pickup is held during a claim', (tester) async {
      feed.requests = [
        request(from: 'Shekilango', price: 1500, metres: 880),
        request(from: 'Ubungo Mataa', price: 1800, metres: 1200, id: 'r2'),
      ];
      await pumpFeed(tester);

      feed.claimGate = Completer<void>();
      final pending = controller(tester).claim(feed.requests.first);
      await tester.pump();

      for (final label in ['Claiming…', 'Pickup']) {
        expect(
          tester
              .widget<NjButton>(find.widgetWithText(NjButton, label))
              .onPressed,
          isNull,
          reason: '$label should be held while a claim is in flight',
        );
      }

      feed.claimGate!.complete();
      await pending;
      await tester.pumpAndSettle();
    });

    testWidgets('a dropped connection mid-claim says nobody knows yet',
        (tester) async {
      // The one honest "do not know". The feed is re-read straight after,
      // and the seat count is what settles it.
      feed.claimResult = const ClaimResult(ClaimOutcome.offline);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      await tester.tap(find.widgetWithText(NjButton, 'Pickup'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('checking whether the seat is yours'),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('claiming with no session does not reach the server',
        (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      final feedController = controller(tester);
      sessions.session = null;
      await sessionControllerOf(tester, find.byType(DriverFeedScreen))
          .refresh();
      await tester.pumpAndSettle();

      final result = await feedController.claim(
        request(from: 'Shekilango', price: 1500, metres: 880),
      );
      expect(result.outcome, ClaimOutcome.noSession);
      expect(feed.claimed, isEmpty);
    });

    testWidgets('the band is in Kiswahili', (tester) async {
      feed.claimResult = const ClaimResult(ClaimOutcome.alreadyTaken);
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester, locale: NjLocale.sw);

      expect(find.widgetWithText(NjButton, 'Chukua'), findsOneWidget);
      await tester.tap(find.widgetWithText(NjButton, 'Chukua'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Imechukuliwa na dereva mwingine'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('a won claim in Kiswahili names the stop', (tester) async {
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester, locale: NjLocale.sw);

      await tester.tap(find.widgetWithText(NjButton, 'Chukua'));
      await tester.pumpAndSettle();

      expect(
        find.text('Siti ni yako · abiria yuko Shekilango'),
        findsOneWidget,
      );
      await drain(tester);
    });
  });
}
