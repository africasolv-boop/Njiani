import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../data/supabase_client.dart';
import '../driver/driver.dart';
import '../driver/session_controller.dart';
import '../places/place.dart';
import 'request_repository.dart';
import 'ride_request.dart';

/// Supplies the [RequestRepository].
final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null
      ? FakeRequestRepository()
      : SupabaseRequestRepository(client);
});

/// The request the passenger is waiting on, or null.
///
/// Rider app only. Null is the signal the screen reads to show the form, so
/// it is a state and not an error.
class RequestController extends AsyncNotifier<RideRequest?> {
  @override
  Future<RideRequest?> build() async {
    final signedIn = ref.watch(authProvider).step == AuthStep.signedIn;
    if (!signedIn) return null;
    return _repository.current();
  }

  RequestRepository get _repository => ref.read(requestRepositoryProvider);

  /// Asks for a seat.
  Future<RideRequest> send({
    required String pickupStageId,
    required String destStageId,
    required VehicleType vehicle,
    required int offerPrice,
  }) async {
    final made = await _repository.create(
      pickupStageId: pickupStageId,
      destStageId: destStageId,
      vehicle: vehicle,
      offerPrice: offerPrice,
    );
    state = AsyncData(made);
    return made;
  }

  /// Withdraws it.
  Future<void> cancel() async {
    await _repository.cancel();
    state = const AsyncData(null);
  }

  /// Re-reads it from the server.
  ///
  /// Also how an expiry is noticed: `current_ride_request()` returns nothing
  /// once `expires_at` has passed, so the screen goes back to the form
  /// without needing to agree with the server about the time.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _repository.current());
    } catch (error, stack) {
      debugPrint('[njiani] could not read the request: $error');
      state = AsyncError(error, stack);
    }
  }
}

/// The passenger's open request.
final requestProvider =
    AsyncNotifierProvider<RequestController, RideRequest?>(
  RequestController.new,
);

/// What drivers usually take for a pair of stages, in a vehicle.
///
/// A family, keyed on all three, so changing the vehicle re-reads the band —
/// the design is explicit that it must, since a boda and a bajaj are not the
/// same trip.
@immutable
class BandKey {
  const BandKey({
    required this.fromStageId,
    required this.toStageId,
    required this.vehicle,
  });

  final String fromStageId;
  final String toStageId;
  final VehicleType vehicle;

  @override
  bool operator ==(Object other) =>
      other is BandKey &&
      other.fromStageId == fromStageId &&
      other.toStageId == toStageId &&
      other.vehicle == vehicle;

  @override
  int get hashCode => Object.hash(fromStageId, toStageId, vehicle);
}

final priceBandProvider =
    FutureProvider.family<PriceBand?, BandKey>((ref, key) async {
  return ref.watch(requestRepositoryProvider).bandFor(
        fromStageId: key.fromStageId,
        toStageId: key.toStageId,
        vehicle: key.vehicle,
      );
});

/// Where the passenger is, and everywhere they could go from there.
///
/// The same question the driver's direction picker asks, and the same two
/// functions answer it — `where_am_i` and `destinations_from_stage`. A
/// passenger choosing a destination and a driver choosing a heading are the
/// same problem seen from two seats.
final pickupOptionsProvider =
    FutureProvider.family<DirectionOptions, Stage?>((ref, from) =>
        ref.watch(directionOptionsProvider(from).future));
