import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Where a driver belongs, case by case.
///
/// Its own file because this is where a real bug lived: an approved driver
/// whose session read failed was left resting on `/`, which rendered a
/// landing placeholder reading "This screen arrives in the next component" —
/// with no way out, and nothing anywhere saying what had gone wrong.
///
/// Two separate fall-throughs did it. Every branch is pinned here now,
/// because the thing they had in common was being unreachable by any test
/// that drove the router normally.
void main() {
  const online = DriverSession(
    id: 'session-1',
    driverId: 'driver-1',
    routeId: 'route-west',
    destStageId: 'west-9',
    vehicleType: VehicleType.bajaj,
    seatsTotal: 3,
    seatsFree: 3,
    online: true,
  );

  const noSession = AsyncData<DriverSession?>(null);
  const loading = AsyncLoading<DriverSession?>();
  final failed = AsyncError<DriverSession?>(
    Exception('is not unique'),
    StackTrace.empty,
  );

  String where({
    required DriverGate gate,
    required AsyncValue<DriverSession?> session,
    String here = NjRoutes.home,
  }) =>
      driverDestination(gate: gate, session: session, here: here);

  // =========================================================================
  group('home is never a resting place', () {
    // THE BUG. An approved driver whose session read failed -- which is what
    // two duplicate `nearest_stage` functions did to every session read --
    // was left on the landing screen.
    test('an approved driver whose session cannot be read gets the picker',
        () {
      expect(
        where(gate: DriverGate.cleared, session: failed),
        NjRoutes.driverDirection,
      );
    });

    // THE OTHER ONE. A failed driver read did the same thing.
    test('a driver record that cannot be read gets the picker too', () {
      expect(
        where(gate: DriverGate.unreadable, session: noSession),
        NjRoutes.driverDirection,
      );
    });

    // The invariant, stated once over every combination rather than as a
    // list of the two that happened to break.
    test('once anything is known, home is never where a driver is left', () {
      for (final gate in DriverGate.values) {
        for (final session in [noSession, loading, failed]) {
          // The session only matters once the driver record says `cleared`:
          // an unreadable driver record is already an answer, whatever the
          // session is doing.
          final stillReading = gate == DriverGate.loading ||
              (gate == DriverGate.cleared && session is AsyncLoading);
          final destination = where(gate: gate, session: session);

          if (stillReading) {
            // The deliberate exception, and the point of the settling
            // screen: a read that is going to answer is worth a frame.
            expect(
              destination,
              NjRoutes.home,
              reason: 'moving before the answer arrives flickers, and can '
                  'park an online driver on the picker',
            );
          } else {
            expect(
              destination,
              isNot(NjRoutes.home),
              reason: '$gate with $session left the driver on the landing '
                  'screen',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  group('a cold start is not a dead connection', () {
    // The fix for the fall-through broke this, which is how it got its own
    // test: `unknown` covered both a slow read and a failed one, so the rule
    // written for the failure fired on every launch and parked an online
    // driver on the picker -- where the router then correctly left them,
    // because a driver is allowed to visit it.
    test('a slow read waits at home rather than guessing', () {
      expect(where(gate: DriverGate.loading, session: loading), NjRoutes.home);
    });

    test('a slow session read does not move an online driver', () {
      expect(
        where(gate: DriverGate.cleared, session: loading),
        NjRoutes.home,
        reason: 'moving now and back again is a flicker at best',
      );
    });

    test('and once it lands, home becomes the feed', () {
      expect(
        where(gate: DriverGate.cleared, session: const AsyncData(online)),
        NjRoutes.driverFeed,
      );
    });
  });

  // =========================================================================
  group('the verification gate', () {
    test('no application on file', () {
      expect(
        where(gate: DriverGate.signUp, session: noSession),
        NjRoutes.driverSignup,
      );
    });

    test('pending and suspended share a screen', () {
      expect(
        where(gate: DriverGate.pending, session: noSession),
        NjRoutes.driverPending,
      );
      expect(
        where(gate: DriverGate.suspended, session: noSession),
        NjRoutes.driverPending,
      );
    });

    test('rejected', () {
      expect(
        where(gate: DriverGate.rejected, session: noSession),
        NjRoutes.driverRejected,
      );
    });

    // What makes the design's "no back navigation" true without suppressing
    // a single pop: the screens stop existing.
    test('approval takes a driver off every gate screen', () {
      for (final screen in NjRoutes.driverGate) {
        expect(
          where(
            gate: DriverGate.cleared,
            session: const AsyncData(online),
            here: screen,
          ),
          NjRoutes.driverFeed,
        );
        expect(
          where(gate: DriverGate.cleared, session: noSession, here: screen),
          NjRoutes.driverDirection,
        );
      }
    });

    test('an unapproved driver is held on their own gate screen', () {
      expect(
        where(
          gate: DriverGate.pending,
          session: noSession,
          here: NjRoutes.driverFeed,
        ),
        NjRoutes.driverPending,
      );
    });
  });

  // =========================================================================
  group('an online driver may walk back to the picker', () {
    // "already online -> Returning here shows Change, not Go online" from the
    // design. The gate must not bounce them straight out.
    test('and is left there', () {
      expect(
        where(
          gate: DriverGate.cleared,
          session: const AsyncData(online),
          here: NjRoutes.driverDirection,
        ),
        NjRoutes.driverDirection,
      );
    });

    test('but an offline driver is not left on the feed', () {
      // There is nothing in it: the feed is derived from a session.
      expect(
        where(
          gate: DriverGate.cleared,
          session: noSession,
          here: NjRoutes.driverFeed,
        ),
        NjRoutes.driverDirection,
      );
    });
  });
}
