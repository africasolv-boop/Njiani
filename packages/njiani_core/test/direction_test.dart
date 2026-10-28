import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeDriverRepository drivers;
  late FakeSessionRepository sessions;
  late FakePlacesRepository places;
  late FakeDriverLocation location;

  const approved = Driver(
    profileId: 'driver-1',
    vehicleType: VehicleType.bajaj,
    plate: 'T 123 ABC',
    colour: 'Green',
    status: DriverStatus.approved,
    licencePath: 'driver-1/licence.jpg',
  );

  setUp(() {
    auth = FakeAuthRepository();
    drivers = FakeDriverRepository(driver: approved);
    sessions = FakeSessionRepository();
    places = FakePlacesRepository();
    location = FakeDriverLocation();
  });

  tearDown(() {
    auth.dispose();
    drivers.dispose();
  });

  Future<void> pumpDirection(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpScreen(
      tester,
      const DriverDirectionScreen(),
      auth: auth,
      driver: drivers,
      session: sessions,
      places: places,
      location: location,
      locale: locale,
    );
  }

  NjButton primary(WidgetTester tester) => tester.widgetList<NjButton>(
        find.byType(NjButton),
      ).last;

  /// Opens the stage sheet and chooses [name].
  ///
  /// Scrolls to it rather than tapping blind: the sheet's list is bounded and
  /// lazily built, so an entry further down it does not exist in the tree
  /// until it is scrolled to — which is also why a driver can reach it.
  Future<void> pickStage(WidgetTester tester, String name) async {
    await tester.tap(find.text('Choose where you are'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(name),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  // =========================================================================
  group('wktPoint — longitude first, every time', () {
    test('writes POINT(lng lat), not POINT(lat lng)', () {
      // Swapping these puts a driver in Dar es Salaam off the coast of
      // Somalia: close enough to look plausible on a map, far enough that
      // nothing ever matches.
      expect(wktPoint(const LatLng(-6.8104, 39.2206)), 'POINT(39.2206 -6.8104)');
    });
  });

  group('Destination', () {
    test('carries the route, because a stage alone is not a direction', () {
      const west = Destination(
        stage: Stage(id: 's', routeId: 'west', name: 'Kibo', nameSw: 'Kibo', seq: 5),
        routeId: 'west',
        directionLabel: 'Westbound',
        metresAhead: 3776,
      );
      expect(west.routeId, 'west');
      expect(west.kmAhead, closeTo(3.776, 0.001));
    });
  });

  group('DirectionOptions', () {
    test('groups by direction, keeping route order inside each', () {
      const options = DirectionOptions(destinations: [], point: LatLng(0, 0));
      expect(options.byDirection, isEmpty);

      final grouped = DirectionOptions(
        destinations: FakePlacesRepository.defaultDestinations,
        point: const LatLng(0, 0),
      ).byDirection;

      expect(grouped.keys, containsAll(['Westbound', 'Eastbound']));
      expect(
        grouped['Westbound']!.map((d) => d.stage.seq),
        orderedEquals([2, 3, 4, 5, 6, 7, 8, 9]),
      );
    });

    test('a named stage counts as an origin even with no fix', () {
      const named = DirectionOptions(destinations: [], fromStageId: 'west-1');
      expect(named.located, isFalse);
      expect(named.hasOrigin, isTrue,
          reason: 'go_online can still be told where to start the feed');
    });
  });

  // =========================================================================
  group('dDirection — the states in the spec', () {
    testWidgets('a fix names where the driver is standing', (tester) async {
      await pumpDirection(tester);

      expect(find.text('Where are you heading?'), findsOneWidget);
      expect(find.text('Starting from your location'), findsOneWidget);
      expect(find.text(places.nearest!.name), findsOneWidget);
    });

    testWidgets('nothing chosen: the action says so and is disabled',
        (tester) async {
      await pumpDirection(tester);

      expect(find.text("Pick where you're going"), findsOneWidget);
      expect(primary(tester).onPressed, isNull);
    });

    testWidgets('both directions are offered, each headed by its far end',
        (tester) async {
      await pumpDirection(tester);

      // The westbound group ends at Kimara Mwisho; eastbound at the terminal.
      expect(find.text('Towards Kimara Mwisho'), findsOneWidget);
      expect(find.text('Towards Ubungo Bus Terminal'), findsOneWidget);
    });

    testWidgets('destinations are in route order, not alphabetical',
        (tester) async {
      await pumpDirection(tester);

      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      // Shekilango is seq 2 and Bucha is seq 6. Alphabetically it would be
      // the other way round, which is a list nobody can read at a stage.
      expect(shown.indexOf('Shekilango'), lessThan(shown.indexOf('Bucha')));
    });

    testWidgets('choosing a destination names it on the action',
        (tester) async {
      await pumpDirection(tester);

      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();

      expect(find.text('Go online · heading to Kimara Mwisho'), findsOneWidget);
      expect(primary(tester).onPressed, isNotNull);
    });

    testWidgets('going online declares the heading and the route',
        (tester) async {
      await pumpDirection(tester);

      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Go online'));
      await tester.tap(find.textContaining('Go online'));
      await tester.pumpAndSettle();

      expect(sessions.headings, ['west-9']);
      expect(sessions.session?.online, isTrue);
      // The fix goes with it, or the feed starts at the beginning of the road.
      expect(sessions.positions, hasLength(1));
    });

    testWidgets('an open session starts with every seat free', (tester) async {
      await pumpDirection(tester);
      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Go online'));
      await tester.tap(find.textContaining('Go online'));
      await tester.pumpAndSettle();

      expect(sessions.session?.seatsTotal, 3);
      expect(sessions.session?.seatsFree, 3);
    });

    // "Changing direction ends the session and starts a new one. Claimed
    // seats survive" -- so the new session must not re-offer them.
    testWidgets('a driver carrying someone keeps those seats taken',
        (tester) async {
      sessions.seatsHeld = 1;
      await pumpDirection(tester);

      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Go online'));
      await tester.tap(find.textContaining('Go online'));
      await tester.pumpAndSettle();

      expect(sessions.session?.seatsFree, 2,
          reason: 'offering three would sell a seat that is already carrying '
              'somebody');
    });

    testWidgets('already online: the action says Change, not Go online',
        (tester) async {
      sessions.session = const DriverSession(
        id: 'session-1',
        driverId: 'driver-1',
        routeId: 'route-west',
        destStageId: 'west-9',
        vehicleType: VehicleType.bajaj,
        seatsTotal: 3,
        seatsFree: 3,
        online: true,
      );

      await pumpDirection(tester);
      await tester.tap(find.text('Kimara Korogwe'));
      await tester.pumpAndSettle();

      expect(find.text('Change · heading to Kimara Korogwe'), findsOneWidget);
      expect(find.text("You're online"), findsOneWidget);
    });

    testWidgets('going offline ends the session', (tester) async {
      sessions.session = const DriverSession(
        id: 'session-1',
        driverId: 'driver-1',
        routeId: 'route-west',
        destStageId: 'west-9',
        vehicleType: VehicleType.bajaj,
        seatsTotal: 3,
        seatsFree: 3,
        online: true,
      );

      await pumpDirection(tester);
      await tester.tap(find.text('Go offline'));
      await tester.pumpAndSettle();

      expect(sessions.session?.online, isFalse);
    });

    testWidgets('renders in Kiswahili', (tester) async {
      await pumpDirection(tester, locale: NjLocale.sw);

      expect(find.text('Unaelekea wapi?'), findsOneWidget);
      expect(
        find.text('Utaona abiria wanaoelekea njia moja na wewe.'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // No GPS is a supported state, not an error. Every message names the way
  // round as well as the problem.
  // =========================================================================
  group('dDirection — without a fix', () {
    testWidgets('denied: says why, offers the list and offers to re-ask',
        (tester) async {
      location.problem = LocationProblem.denied;
      await pumpDirection(tester);

      expect(find.textContaining('needs your location'), findsOneWidget);
      expect(find.text('Choose where you are'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('denied forever: does not offer to re-ask', (tester) async {
      // Only Settings can undo it, so a Try again button would be a lie.
      location.problem = LocationProblem.deniedForever;
      await pumpDirection(tester);

      expect(find.textContaining('Settings'), findsOneWidget);
      expect(find.text('Choose where you are'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('location switched off: names the switch', (tester) async {
      location.problem = LocationProblem.serviceOff;
      await pumpDirection(tester);

      expect(find.textContaining('switched off'), findsOneWidget);
    });

    testWidgets('timed out: blames the buildings, not the driver',
        (tester) async {
      location.problem = LocationProblem.timedOut;
      await pumpDirection(tester);

      expect(find.textContaining('too many buildings'), findsOneWidget);
    });

    testWidgets('picking a stage by hand gets the same destination list',
        (tester) async {
      location.problem = LocationProblem.denied;
      await pumpDirection(tester);

      await pickStage(tester, 'Ubungo Mataa');

      expect(find.text('Starting from'), findsOneWidget);
      expect(find.text('Kimara Mwisho'), findsOneWidget);
    });

    testWidgets('going online from a named stage sends the stage, not a point',
        (tester) async {
      location.problem = LocationProblem.denied;
      await pumpDirection(tester);

      await pickStage(tester, 'Ubungo Mataa');

      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Go online'));
      await tester.tap(find.textContaining('Go online'));
      await tester.pumpAndSettle();

      // A session with no position is treated as being at the start of the
      // route, which for a driver already halfway along it is a feed full of
      // passengers behind them.
      expect(sessions.origins, ['west-1']);
      expect(sessions.positions, isEmpty);
    });
  });

  // =========================================================================
  // Three situations that produce the same empty destination list, and used
  // to produce the same unhelpful sentence with no way out of any of them.
  // =========================================================================
  group('dDirection — when there is nowhere to go', () {
    testWidgets('an unseeded database says so, and says what to run',
        (tester) async {
      // What the first real run on a hosted project looked like: `db push`
      // applies migrations, `seed.sql` is reference data, and nothing on
      // screen connected the blank line to the missing seed.
      places.routesActive = 0;
      places.onCorridor = false;
      places.destinations = [];
      await pumpDirection(tester);

      expect(find.text('Njiani has no roads set up yet.'), findsOneWidget);
      expect(find.textContaining('seed.sql'), findsOneWidget,
          reason: 'debug builds get the exact fix');
      // No stage picker: there are no stages to pick.
      expect(find.text('Choose where you are'), findsNothing);
    });

    testWidgets('off the corridor says where to drive, and offers the list',
        (tester) async {
      // The common real case: a driver at home, before they have driven to
      // the road. Also what a desktop build in another country looks like.
      places.onCorridor = false;
      places.destinations = [];
      await pumpDirection(tester);

      expect(
        find.text("You're not on a road Njiani covers yet."),
        findsOneWidget,
      );
      expect(find.text('Choose where you are'), findsOneWidget);
    });

    testWidgets('the end of the road offers the way back', (tester) async {
      places.destinations = [];
      await pumpDirection(tester);

      expect(find.text("You're at the end of this road."), findsOneWidget);
      expect(find.text('Choose where you are'), findsOneWidget);
    });

    testWidgets('a stage far from any road is not claimed as your location',
        (tester) async {
      // nearest_stage had no radius, so a point in Amsterdam came back as
      // Kimara Mwisho, 7,315 km away, printed under "Starting from your
      // location" as though it were a fact.
      places.onCorridor = false;
      places.destinations = [];
      await pumpDirection(tester);

      final row = tester.widget<NjWhereRow>(find.byType(NjWhereRow));
      expect(row.fromValue, isEmpty);
    });
  });

  group('dDirection — refusals from the server', () {
    testWidgets('an unapproved driver is told, not left guessing',
        (tester) async {
      sessions.failure = const DriverError(DriverFailure.notApproved);
      await pumpDirection(tester);

      await tester.tap(find.text('Kimara Mwisho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Go online'));
      await tester.tap(find.textContaining('Go online'));
      await tester.pumpAndSettle();

      expect(
        find.text("Your account isn't approved to drive yet."),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  group('the session itself', () {
    test('seats taken is what is not free', () {
      const session = DriverSession(
        id: 's',
        driverId: 'd',
        routeId: 'r',
        destStageId: 'x',
        vehicleType: VehicleType.bajaj,
        seatsTotal: 3,
        seatsFree: 1,
        online: true,
      );
      expect(session.seatsTaken, 2);
      expect(session.isFull, isFalse);
    });

    test('a row reads as the database writes it', () {
      final session = DriverSession.fromRow(const {
        'id': 'session-1',
        'driver_id': 'driver-1',
        'route_id': 'route-west',
        'dest_stage_id': 'west-9',
        'vehicle_type': 'boda',
        'seats_total': 1,
        'seats_free': 0,
        'status': 'online',
      });

      expect(session.vehicleType, VehicleType.boda);
      expect(session.isFull, isTrue);
      expect(session.online, isTrue);
    });

    test('an offline row is not online', () {
      final session = DriverSession.fromRow(const {
        'id': 's',
        'driver_id': 'd',
        'route_id': 'r',
        'dest_stage_id': 'x',
        'vehicle_type': 'bajaj',
        'seats_total': 3,
        'seats_free': 3,
        'status': 'offline',
      });
      expect(session.online, isFalse);
    });
  });
}
