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

    testWidgets('Pickup says what it is waiting for, and cannot be tapped',
        (tester) async {
      // C10 wires the atomic claim. A button that silently does nothing
      // teaches a driver the app is broken.
      feed.requests = [request(from: 'Shekilango', price: 1500, metres: 880)];
      await pumpFeed(tester);

      final button = tester.widget<NjButton>(
        find.widgetWithText(NjButton, 'Pickup arrives next'),
      );
      expect(button.onPressed, isNull);
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
}
