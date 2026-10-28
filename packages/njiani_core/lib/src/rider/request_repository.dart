import 'package:supabase_flutter/supabase_flutter.dart';

import '../driver/driver.dart';
import '../driver/driver_repository.dart';
import 'ride_request.dart';

/// Why a request could not be made.
enum RequestFailure {
  notSignedIn,

  /// The two stages are not a trip: different routes, the same stage, or a
  /// destination behind the pickup. Each would write a row that saves and
  /// then matches nothing, which is why the server refuses it.
  notATrip,

  /// A request is already waiting. One per passenger: two would let one
  /// person hold two seats on the same road and strand the second driver.
  alreadyWaiting,

  offline,
  unknown,
}

/// A failure with the server's own words kept.
class RequestError implements Exception {
  const RequestError(this.failure, {this.detail});

  final RequestFailure failure;
  final String? detail;

  @override
  String toString() =>
      'RequestError(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Asking for a seat, and withdrawing the ask.
abstract interface class RequestRepository {
  /// What drivers usually take for this pair, or null if it has never been
  /// priced. Null is an answer: a made-up band is worse than none, because a
  /// passenger anchors to it.
  Future<PriceBand?> bandFor({
    required String fromStageId,
    required String toStageId,
    required VehicleType vehicle,
  });

  /// The request the passenger is waiting on, if any.
  Future<RideRequest?> current();

  /// Makes the request. The route and the pickup point are resolved on the
  /// server; the price is the passenger's.
  Future<RideRequest> create({
    required String pickupStageId,
    required String destStageId,
    required VehicleType vehicle,
    required int offerPrice,
  });

  /// Withdraws it. The row is kept, cancelled — an unmatched request carries
  /// its offer and its time of day, which is the pricing dataset.
  Future<void> cancel();
}

/// Backed by the C8 functions.
class SupabaseRequestRepository implements RequestRepository {
  const SupabaseRequestRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PriceBand?> bandFor({
    required String fromStageId,
    required String toStageId,
    required VehicleType vehicle,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'price_band',
        params: {
          'p_from_stage': fromStageId,
          'p_to_stage': toStageId,
          'p_vehicle': vehicle.code,
        },
      );
      if (rows.isEmpty) return null;
      return PriceBand.fromRow(rows.first as Map<String, dynamic>);
    } catch (_) {
      // A missing hint is not worth an error on screen. The field still
      // works and the request still sends.
      return null;
    }
  }

  @override
  Future<RideRequest?> current() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('current_ride_request');
      if (rows.isEmpty) return null;
      return RideRequest.fromRow(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw RequestError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<RideRequest> create({
    required String pickupStageId,
    required String destStageId,
    required VehicleType vehicle,
    required int offerPrice,
  }) async {
    try {
      await _client.rpc<Map<String, dynamic>>(
        'create_ride_request',
        params: {
          'p_pickup_stage_id': pickupStageId,
          'p_dest_stage_id': destStageId,
          'p_vehicle_type': vehicle.code,
          'p_offer_price': offerPrice,
        },
      );
    } on PostgrestException catch (error) {
      throw RequestError(_classify(error), detail: error.message);
    } catch (error) {
      throw RequestError(RequestFailure.offline, detail: '$error');
    }

    // Read it back rather than parsing the function's row: `current()`
    // resolves the place names the waiting panel shows, and this is the one
    // moment where an extra round trip buys something.
    final made = await current();
    if (made == null) {
      throw const RequestError(RequestFailure.unknown);
    }
    return made;
  }

  @override
  Future<void> cancel() async {
    try {
      await _client.rpc<void>('cancel_ride_request');
    } on PostgrestException catch (error) {
      throw RequestError(_classify(error), detail: error.message);
    }
  }

  static RequestFailure _classify(PostgrestException error) =>
      switch (error.code) {
        '23505' => RequestFailure.alreadyWaiting,
        '22023' => RequestFailure.notATrip,
        '28000' || '42501' => RequestFailure.notSignedIn,
        _ => error.message.toLowerCase().contains('failed host lookup')
            ? RequestFailure.offline
            : RequestFailure.unknown,
      };
}

/// In-memory requests, for tests and for running without a backend.
class FakeRequestRepository implements RequestRepository {
  FakeRequestRepository({this.request, this.band = const PriceBand(
    low: 1700,
    high: 2500,
    mid: 2100,
  )});

  RideRequest? request;

  /// What [bandFor] returns. Null models a pair nobody has priced.
  PriceBand? band;

  /// Requests made, in order.
  final List<RideRequest> created = [];

  /// How many times the request was withdrawn.
  int cancels = 0;

  RequestError? failure;

  int _next = 0;

  @override
  Future<PriceBand?> bandFor({
    required String fromStageId,
    required String toStageId,
    required VehicleType vehicle,
  }) async =>
      band;

  @override
  Future<RideRequest?> current() async {
    if (failure != null) throw failure!;
    return request;
  }

  @override
  Future<RideRequest> create({
    required String pickupStageId,
    required String destStageId,
    required VehicleType vehicle,
    required int offerPrice,
  }) async {
    if (failure != null) throw failure!;
    if (request != null) {
      throw const RequestError(RequestFailure.alreadyWaiting);
    }

    final made = RideRequest(
      id: 'request-${++_next}',
      pickupStageId: pickupStageId,
      destStageId: destStageId,
      vehicleType: vehicle,
      offerPrice: offerPrice,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      createdAt: DateTime.now(),
      pickupName: 'Ubungo Mataa',
      pickupNameSw: 'Ubungo Mataa',
      destName: 'Kimara Mwisho',
      destNameSw: 'Kimara Mwisho',
    );
    created.add(made);
    request = made;
    return made;
  }

  @override
  Future<void> cancel() async {
    if (failure != null) throw failure!;
    cancels++;
    request = null;
  }
}

/// Maps a request failure onto something the screen can say.
///
/// `DriverError` has its own map for the same reason: one switch, so a new
/// case cannot be forgotten on one screen out of three.
RequestFailure requestFailureOf(Object error) => error is RequestError
    ? error.failure
    : error is DriverError && error.failure == DriverFailure.offline
        ? RequestFailure.offline
        : RequestFailure.unknown;
