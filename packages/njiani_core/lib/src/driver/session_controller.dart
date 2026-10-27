import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../data/supabase_client.dart';
import '../places/place.dart';
import '../places/places_repository.dart';
import 'driver.dart';
import 'driver_controller.dart';
import 'driver_location.dart';
import 'driver_session.dart';
import 'session_repository.dart';

/// Supplies the [PlacesRepository].
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null
      ? FakePlacesRepository()
      : SupabasePlacesRepository(client);
});

/// Supplies the [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null
      ? FakeSessionRepository()
      : SupabaseSessionRepository(client);
});

/// The driver's open session, or null when they are offline.
///
/// Driver app only. Rebuilds when the session appears or disappears, and the
/// router reads it to decide whether the direction picker is where the driver
/// belongs.
class SessionController extends AsyncNotifier<DriverSession?> {
  @override
  Future<DriverSession?> build() async {
    final signedIn = ref.watch(authProvider).step == AuthStep.signedIn;
    if (!signedIn) return null;

    // Only an approved driver can have one. Watching rather than reading, so
    // an approval arriving over realtime re-evaluates this too.
    final approved = ref.watch(driverProvider).valueOrNull?.status ==
        DriverStatus.approved;
    if (!approved) return null;

    return _repository.current();
  }

  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  /// Declares a heading and goes online, replacing any session already open.
  Future<DriverSession> goOnline({
    required String routeId,
    required String destStageId,
    LatLng? position,
    String? fromStageId,
  }) async {
    final opened = await _repository.goOnline(
      routeId: routeId,
      destStageId: destStageId,
      position: position,
      fromStageId: fromStageId,
    );
    state = AsyncData(opened);
    return opened;
  }

  /// Ends the session. Claimed seats are untouched.
  Future<void> goOffline() async {
    await _repository.goOffline();
    state = const AsyncData(null);
  }

  /// Sends a position for the feed to be computed from.
  ///
  /// Throttled: the caller decides how often, and the repository swallows
  /// failures. Battery and data cost a driver real money, and a dropped
  /// update costs nothing — the next one is seconds away.
  Future<void> reportPosition(LatLng point) =>
      _repository.reportPosition(point);

  /// Re-reads the session from the server.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _repository.current());
    } catch (error, stack) {
      debugPrint('[njiani] could not read the session: $error');
      state = AsyncError(error, stack);
    }
  }
}

/// The driver's open session.
final sessionProvider =
    AsyncNotifierProvider<SessionController, DriverSession?>(
  SessionController.new,
);

/// Where the driver is standing, and what is ahead of them.
///
/// One provider rather than three calls from the screen, because the three
/// move together: a position gives a nearest stage and a destination list,
/// and a refusal gives neither plus a reason to show.
@immutable
class DirectionOptions {
  const DirectionOptions({
    required this.destinations,
    this.from,
    this.point,
    this.fromStageId,
    this.problem,
  });

  /// Everywhere the driver could head for, in route order.
  final List<Destination> destinations;

  /// Where they are starting from, named.
  final Stage? from;

  /// The fix the list was built from, passed to `go_online` so the feed has
  /// somewhere to start.
  final LatLng? point;

  /// The stage the driver named, when there was no fix. `go_online` takes it
  /// instead and reads the coordinates itself — a session with no position
  /// is treated as being at the start of the route, which for a driver
  /// already halfway along it means a feed full of passengers behind them.
  final String? fromStageId;

  /// Why there is no position, if there isn't one. Not an error: the screen
  /// falls back to picking a starting stage by hand.
  final LocationProblem? problem;

  bool get located => point != null;

  /// True once there is somewhere to start the feed from, however it
  /// was arrived at.
  bool get hasOrigin => point != null || fromStageId != null;

  /// The destinations, grouped by direction, in the order the routes came
  /// back. Both directions are offered — a driver at Ubungo may be heading
  /// either way, and the list is how they say which.
  Map<String, List<Destination>> get byDirection {
    final grouped = <String, List<Destination>>{};
    for (final destination in destinations) {
      grouped.putIfAbsent(destination.directionLabel, () => []).add(destination);
    }
    return grouped;
  }
}

/// Resolves a position into a starting stage and a destination list.
///
/// Takes the stage to start from, or null to ask the device where it is. The
/// manual case is the no-GPS fallback: the driver picks the stage they are
/// standing at and the same query runs from its coordinates.
final directionOptionsProvider =
    FutureProvider.family<DirectionOptions, Stage?>((ref, from) async {
  final places = ref.watch(placesRepositoryProvider);

  if (from != null) {
    // A stage the driver named. The server resolves it to coordinates and
    // runs the same query, so there is one answer to "what is ahead of me"
    // rather than two that can drift apart.
    return DirectionOptions(
      destinations: await places.destinationsFromStage(from.id),
      from: from,
      fromStageId: from.id,
    );
  }

  final fix = await ref.watch(driverLocationProvider).current();
  if (!fix.hasPoint) {
    return DirectionOptions(destinations: const [], problem: fix.problem);
  }

  final point = fix.point!;
  final (nearest, destinations) = await (
    places.nearestStage(point),
    places.destinationsAhead(point),
  ).wait;

  return DirectionOptions(
    destinations: destinations,
    from: nearest,
    point: point,
  );
});
