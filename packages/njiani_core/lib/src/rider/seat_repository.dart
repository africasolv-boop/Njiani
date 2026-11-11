import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_repository.dart';
import 'trip_seat.dart';

/// The passenger's side of a claimed seat.
///
/// Reading it, watching it, and giving it up. The claim itself is the
/// driver's action — see `FeedRepository.claim`.
abstract interface class SeatRepository {
  /// The seat the passenger holds, or null.
  Future<TripSeat?> current();

  /// Gives it up. Free until the driver arrives, and the design says so on
  /// the button.
  ///
  /// Does **not** put the request back on the road. A passenger who no longer
  /// wants the trip has not asked to be matched again, and reopening it would
  /// send another driver to a stage nobody is waiting at. The driver's seat is
  /// freed, which is the part that matters to somebody else.
  Future<void> cancel();

  /// Fires when this passenger's seat row changes.
  ///
  /// Unlike the driver's feed, this is a real subscription: `trip_seats`
  /// carries a read policy for both parties to a seat, so there is something
  /// for realtime to filter and nothing is leaked by watching it. The driver
  /// feed has to use a broadcast nudge precisely because `ride_requests` has
  /// no such policy.
  Stream<void> changes();
}

/// Backed by `current_trip_seat()` and `cancel_my_seat()`.
class SupabaseSeatRepository implements SeatRepository {
  const SupabaseSeatRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<TripSeat?> current() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('current_trip_seat');
      if (rows.isEmpty) return null;
      return TripSeat.fromRow(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw RequestError(_classify(error), detail: error.message);
    } catch (error) {
      throw RequestError(RequestFailure.offline, detail: '$error');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _client.rpc<List<dynamic>>('cancel_my_seat');
    } on PostgrestException catch (error) {
      throw RequestError(_classify(error), detail: error.message);
    } catch (error) {
      throw RequestError(RequestFailure.offline, detail: '$error');
    }
  }

  @override
  Stream<void> changes() {
    final id = _userId;
    if (id == null) return const Stream<void>.empty();

    // Filtered on the passenger, which the table's read policy already
    // enforces. Stating it here as well is not belt and braces for secrecy —
    // it is what stops the client being woken for every seat in the city.
    //
    // The payload is deliberately ignored. A changed row means "re-read",
    // and `current_trip_seat()` is the only thing that can answer, because
    // the row alone carries no driver name, plate or phone number.
    return _client
        .from('trip_seats')
        .stream(primaryKey: ['id'])
        .eq('passenger_id', id)
        .map((_) {});
  }

  static RequestFailure _classify(PostgrestException error) =>
      switch (error.code) {
        '28000' || '42501' => RequestFailure.notSignedIn,
        _ => error.message.toLowerCase().contains('failed host lookup')
            ? RequestFailure.offline
            : RequestFailure.unknown,
      };
}

/// In-memory seat, for tests and for running without a backend.
class FakeSeatRepository implements SeatRepository {
  FakeSeatRepository({this.seat});

  TripSeat? seat;

  /// How many times the passenger gave the seat up.
  int cancels = 0;

  RequestError? failure;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Pushes a seat and wakes anything watching, the way a realtime row change
  /// does.
  void emit(TripSeat? next) {
    seat = next;
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<TripSeat?> current() async {
    if (failure != null) throw failure!;
    return seat;
  }

  @override
  Future<void> cancel() async {
    if (failure != null) throw failure!;
    cancels++;
    seat = null;
  }

  @override
  Stream<void> changes() => _changes.stream;

  void dispose() => _changes.close();
}
