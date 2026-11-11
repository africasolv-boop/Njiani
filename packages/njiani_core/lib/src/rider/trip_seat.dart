import 'package:flutter/foundation.dart';

import '../driver/driver.dart';
import '../locale/nj_locale.dart';

/// Where one seat on one trip has got to.
///
/// Mirrors `public.seat_state`. Each seat is its own row with its own price —
/// never one trip carrying three passengers — which is what makes a bajaj
/// filling up seat by seat expressible at all.
enum SeatState {
  /// A driver has it and is on the way. Phone numbers are revealed.
  claimed('claimed'),

  /// The passenger is in the vehicle.
  aboard('aboard'),

  /// Set down. The trip is over.
  dropped('dropped'),

  /// Either side called it off.
  cancelled('cancelled');

  const SeatState(this.code);

  final String code;

  /// True while the two parties are still in contact over this seat. The
  /// phone numbers are revealed in exactly these states and no others — see
  /// `current_trip_seat()`, which filters on them in SQL rather than
  /// trusting a client to.
  bool get isLive => this == SeatState.claimed || this == SeatState.aboard;

  /// An unrecognised value is treated as [dropped].
  ///
  /// The conservative direction: a state a future release adds must never be
  /// mistaken for a live one by an old binary, because "live" is what puts a
  /// stranger's phone number on screen.
  static SeatState parse(String? code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return SeatState.dropped;
  }
}

/// The seat a passenger holds, and who is coming for it.
///
/// Built from `current_trip_seat()`, which is the only way a passenger reads
/// a driver's name, plate or phone number. There is no read policy that would
/// let them query `drivers` or `profiles` directly — the reveal is scoped to
/// a live seat, in one `security definer` function, because that is the only
/// place the scope can be stated once and enforced for both parties.
@immutable
class TripSeat {
  const TripSeat({
    required this.id,
    required this.state,
    required this.price,
    required this.driverName,
    required this.driverPhone,
    required this.plate,
    required this.colour,
    required this.vehicleType,
    this.claimedAt,
    this.pickupName,
    this.pickupNameSw,
    this.destName,
    this.destNameSw,
    this.rating,
    this.tripsCount = 0,
    this.seatsTaken = 1,
    this.metresAway,
  });

  factory TripSeat.fromRow(Map<String, dynamic> row) => TripSeat(
        id: row['seat_id'] as String,
        state: SeatState.parse(row['state'] as String?),
        price: (row['price'] as num?)?.toInt() ?? 0,
        claimedAt: DateTime.tryParse(row['claimed_at'] as String? ?? ''),
        pickupName: row['pickup_name'] as String?,
        pickupNameSw: row['pickup_name_sw'] as String?,
        destName: row['dest_name'] as String?,
        destNameSw: row['dest_name_sw'] as String?,
        driverName: row['driver_name'] as String? ?? '',
        driverPhone: row['driver_phone'] as String? ?? '',
        plate: row['plate'] as String? ?? '',
        colour: row['colour'] as String? ?? '',
        vehicleType: VehicleType.tryParse(row['vehicle_type'] as String?) ??
            VehicleType.bajaj,
        rating: (row['rating'] as num?)?.toDouble(),
        tripsCount: (row['trips_count'] as num?)?.toInt() ?? 0,
        seatsTaken: (row['seats_taken'] as num?)?.toInt() ?? 1,
        metresAway: (row['metres_away'] as num?)?.toDouble(),
      );

  final String id;
  final SeatState state;

  /// Fixed at the moment of the claim, in the database, from the offer the
  /// passenger made. It cannot move afterwards — that is the whole promise
  /// of agreeing a price before pickup.
  final int price;

  final DateTime? claimedAt;

  final String? pickupName;
  final String? pickupNameSw;
  final String? destName;
  final String? destNameSw;

  final String driverName;

  /// Readable only while [state] is live, and only by this seat's two
  /// parties. Enforced in SQL, not here.
  final String driverPhone;

  /// The trust anchor. A passenger verifies the bajaj that pulls up by
  /// reading its plate, so the design shows it larger than the name.
  final String plate;

  /// One canonical English value from `VehicleColour`, localised for display.
  final String colour;

  final VehicleType vehicleType;

  /// Null until the driver has been rated at all. Null is an answer: a
  /// made-up 5.0 on a driver's first trip is a lie a passenger acts on.
  final double? rating;

  final int tripsCount;

  /// Seats occupied in the vehicle, this passenger included. One more than
  /// the number of people they will be sharing with.
  final int seatsTaken;

  /// Straight-line metres between the driver's last reported position and
  /// the pickup point. Null when the driver has sent no fix yet.
  final double? metresAway;

  String? pickupLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (pickupNameSw ?? pickupName) : pickupName;

  String? destLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (destNameSw ?? destName) : destName;

  bool get isLive => state.isLive;

  bool get isAboard => state == SeatState.aboard;

  /// People sharing the vehicle, this passenger not counted.
  int get othersAboard => seatsTaken <= 1 ? 0 : seatsTaken - 1;

  bool get hasPhone => driverPhone.trim().isNotEmpty;

  /// Minutes until the driver reaches the pickup point.
  ///
  /// Haversine over the straight line, divided by 18 km/h — D8, which is the
  /// MVP routing answer until C14 puts a self-hosted OSRM behind it. The
  /// server has already done the distance in PostGIS; this is the division.
  ///
  /// Null when there is no fix to divide. Never zero and never seconds: a
  /// minute is the smallest unit this estimate can honestly carry, and
  /// "arriving in 40 seconds" from a straight line over Dar es Salaam
  /// traffic is a number nobody should be shown.
  int? get etaMinutes {
    final metres = metresAway;
    if (metres == null) return null;
    if (metres <= arrivedWithinMetres) return 0;

    // 18 km/h is 300 metres a minute.
    return (metres / 300).ceil().clamp(1, 60);
  }

  /// Close enough that the passenger should be looking for the vehicle
  /// rather than reading an estimate.
  ///
  /// A stage is tens of metres across and a GPS fix in a built-up street is
  /// good to perhaps twenty, so anything inside this is "here" and counting
  /// it down further would be false precision.
  static const double arrivedWithinMetres = 80;

  /// True once the driver is at the pickup point.
  ///
  /// Also true once the passenger is aboard, which is the state that follows
  /// it: a seat cannot be aboard without the vehicle having arrived.
  bool get hasArrived =>
      isAboard ||
      (metresAway != null && metresAway! <= arrivedWithinMetres);

  @override
  bool operator ==(Object other) =>
      other is TripSeat &&
      other.id == id &&
      other.state == state &&
      other.metresAway == metresAway &&
      other.seatsTaken == seatsTaken;

  @override
  int get hashCode => Object.hash(id, state, metresAway, seatsTaken);

  @override
  String toString() => 'TripSeat($id, ${state.code}, $plate, $price)';
}
