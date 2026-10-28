import 'package:flutter/foundation.dart';

import '../driver/driver.dart';
import '../locale/nj_locale.dart';

/// What drivers on this pair of stages usually take.
///
/// A hint, never a rule. An offer below it still sends — the passenger sets
/// the price, and a rejected offer tells us more about the floor than an
/// accepted one does (ARCHITECTURE §7).
@immutable
class PriceBand {
  const PriceBand({required this.low, required this.high, required this.mid});

  factory PriceBand.fromRow(Map<String, dynamic> row) => PriceBand(
        low: (row['low'] as num).toInt(),
        high: (row['high'] as num).toInt(),
        mid: (row['mid'] as num).toInt(),
      );

  final int low;
  final int high;

  /// Halfway, rounded to the nearest hundred. Nobody offers TSh 1,137.
  final int mid;

  /// The three chips, in order. De-duplicated: a narrow band can round to the
  /// same number twice, and two identical chips look like a bug.
  List<int> get chips {
    final seen = <int>{};
    return [low, mid, high].where(seen.add).toList();
  }

  bool isBelow(int price) => price < low;

  @override
  bool operator ==(Object other) =>
      other is PriceBand && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => 'PriceBand($low–$high)';
}

/// The passenger's own request, while it is waiting.
@immutable
class RideRequest {
  const RideRequest({
    required this.id,
    required this.pickupStageId,
    required this.destStageId,
    required this.vehicleType,
    required this.offerPrice,
    required this.expiresAt,
    this.pickupName,
    this.pickupNameSw,
    this.destName,
    this.destNameSw,
    this.createdAt,
  });

  factory RideRequest.fromRow(Map<String, dynamic> row) => RideRequest(
        id: row['id'] as String,
        pickupStageId: row['pickup_stage_id'] as String? ?? '',
        destStageId: row['dest_stage_id'] as String? ?? '',
        vehicleType: VehicleType.tryParse(row['vehicle_type'] as String?) ??
            VehicleType.bajaj,
        offerPrice: (row['offer_price'] as num?)?.toInt() ?? 0,
        expiresAt:
            DateTime.tryParse(row['expires_at'] as String? ?? '') ??
                DateTime.now(),
        pickupName: row['pickup_name'] as String?,
        pickupNameSw: row['pickup_name_sw'] as String?,
        destName: row['dest_name'] as String?,
        destNameSw: row['dest_name_sw'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  final String id;
  final String pickupStageId;
  final String destStageId;
  final VehicleType vehicleType;
  final int offerPrice;

  /// Ten minutes from creation, matching the copy on the screen.
  final DateTime expiresAt;

  final String? pickupName;
  final String? pickupNameSw;
  final String? destName;
  final String? destNameSw;
  final DateTime? createdAt;

  String? pickupLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (pickupNameSw ?? pickupName) : pickupName;

  String? destLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (destNameSw ?? destName) : destName;

  /// How long is left, never negative.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool hasExpired(DateTime now) => !expiresAt.isAfter(now);

  @override
  bool operator ==(Object other) => other is RideRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RideRequest($pickupName → $destName, $offerPrice, ${vehicleType.code})';
}
