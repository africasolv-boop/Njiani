import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../places/place.dart';
import '../places/places_repository.dart';
import 'driver.dart';
import 'driver_repository.dart';
import 'driver_session.dart';

/// Opening, changing and ending a driver's session.
abstract interface class SessionRepository {
  /// The caller's online session, or null if they are offline.
  Future<DriverSession?> current();

  /// Declares a heading and opens a session.
  ///
  /// Ends any session already open, which is how changing direction works —
  /// `driver_sessions_one_online_idx` makes being online twice impossible, so
  /// there is no second path.
  Future<DriverSession> goOnline({
    required String routeId,
    required String destStageId,
    LatLng? position,
    String? fromStageId,
  });

  /// Ends the session. Does not touch claimed seats: closing an app is not a
  /// cancellation, and the driver still owes those passengers the trip.
  Future<void> goOffline();

  /// Updates the position the feed is computed from.
  Future<void> reportPosition(LatLng point);
}

/// Backed by the C7 functions.
class SupabaseSessionRepository implements SessionRepository {
  const SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DriverSession?> current() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;

    try {
      // Through the function, not the table: it resolves the destination and
      // the driver's nearest stage in the same round trip, which the route
      // board needs and which would otherwise be two more calls on a
      // connection the driver pays for.
      final rows = await _client.rpc<List<dynamic>>('current_driver_session');
      if (rows.isEmpty) return null;
      return DriverSession.fromRow(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<DriverSession> goOnline({
    required String routeId,
    required String destStageId,
    LatLng? position,
    String? fromStageId,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'go_online',
        params: {
          'p_route_id': routeId,
          'p_dest_stage_id': destStageId,
          'p_pos': position == null ? null : wktPoint(position),
          'p_from_stage_id': fromStageId,
        },
      );
      return DriverSession.fromRow(row);
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<void> goOffline() async {
    try {
      await _client.rpc<void>('go_offline');
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<void> reportPosition(LatLng point) async {
    // Deliberately swallowed. A position update is a best-effort improvement
    // to the feed, not something a driver asked for, and surfacing a failure
    // would put an error on screen for something they cannot act on. The next
    // one is seconds away.
    try {
      await _client.rpc<void>(
        'report_position',
        params: {'p_pos': wktPoint(point)},
      );
    } catch (_) {
      // Ignored on purpose. See above.
    }
  }

  /// Maps the SQLSTATEs `go_online` raises deliberately.
  static DriverFailure _classify(PostgrestException error) =>
      switch (error.code) {
        // The C6 gate, or a column the driver may not write.
        '42501' => DriverFailure.notApproved,
        '28000' => DriverFailure.notSignedIn,
        // No driver row at all.
        'P0002' => DriverFailure.staleState,
        // A destination that is not on the route, or every seat taken.
        '22023' => DriverFailure.staleState,
        _ => error.message.toLowerCase().contains('failed host lookup')
            ? DriverFailure.offline
            : DriverFailure.unknown,
      };
}

/// In-memory sessions, for tests and for running without a backend.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({
    this.session,
    this.driverId = 'driver-1',
    this.vehicleType = VehicleType.bajaj,
    this.seatsHeld = 0,
  });

  DriverSession? session;
  final String driverId;
  VehicleType vehicleType;

  /// Seats already carrying somebody, which a new session must not re-offer.
  int seatsHeld;

  /// Headings declared, in order.
  final List<String> headings = [];

  /// Positions reported, in order.
  final List<LatLng> positions = [];

  /// Starting stages named by hand, in order — the no-GPS path.
  final List<String> origins = [];

  DriverError? failure;

  int _opened = 0;

  @override
  Future<DriverSession?> current() async {
    if (failure != null) throw failure!;
    return session?.online == true ? session : null;
  }

  @override
  Future<DriverSession> goOnline({
    required String routeId,
    required String destStageId,
    LatLng? position,
    String? fromStageId,
  }) async {
    if (failure != null) throw failure!;

    headings.add(destStageId);
    if (fromStageId != null) origins.add(fromStageId);
    if (position != null) positions.add(position);

    final total = vehicleType.seats;
    final opened = DriverSession(
      id: 'session-${++_opened}',
      driverId: driverId,
      routeId: routeId,
      destStageId: destStageId,
      vehicleType: vehicleType,
      seatsTotal: total,
      seatsFree: total - seatsHeld,
      online: true,
      wentOnlineAt: DateTime.now(),
    );
    session = opened;
    return opened;
  }

  @override
  Future<void> goOffline() async {
    if (failure != null) throw failure!;
    final open = session;
    if (open == null) return;
    session = DriverSession(
      id: open.id,
      driverId: open.driverId,
      routeId: open.routeId,
      destStageId: open.destStageId,
      vehicleType: open.vehicleType,
      seatsTotal: open.seatsTotal,
      seatsFree: open.seatsFree,
      online: false,
      wentOnlineAt: open.wentOnlineAt,
    );
  }

  @override
  Future<void> reportPosition(LatLng point) async {
    positions.add(point);
  }
}
