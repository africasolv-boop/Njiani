import 'package:flutter/foundation.dart';

import '../locale/nj_locale.dart';
import 'driver.dart';

/// A driver who has declared a heading and gone online.
///
/// The row that makes Njiani not a ride-hailing app: the direction is chosen
/// **before** a single request is seen, and the feed at C9 is derived from
/// this, not from a radius around the driver.
@immutable
class DriverSession {
  const DriverSession({
    required this.id,
    required this.driverId,
    required this.routeId,
    required this.destStageId,
    required this.vehicleType,
    required this.seatsTotal,
    required this.seatsFree,
    required this.online,
    this.wentOnlineAt,
    this.destName,
    this.destNameSw,
    this.fromName,
    this.fromNameSw,
  });

  factory DriverSession.fromRow(Map<String, dynamic> row) => DriverSession(
        id: row['id'] as String,
        driverId: row['driver_id'] as String? ?? '',
        routeId: row['route_id'] as String? ?? '',
        destStageId: row['dest_stage_id'] as String? ?? '',
        vehicleType: VehicleType.tryParse(row['vehicle_type'] as String?) ??
            VehicleType.bajaj,
        seatsTotal: (row['seats_total'] as num?)?.toInt() ?? 0,
        seatsFree: (row['seats_free'] as num?)?.toInt() ?? 0,
        online: (row['status'] as String?) == 'online',
        wentOnlineAt:
            DateTime.tryParse(row['went_online_at'] as String? ?? ''),
        destName: row['dest_name'] as String?,
        destNameSw: row['dest_name_sw'] as String?,
        fromName: row['from_name'] as String?,
        fromNameSw: row['from_name_sw'] as String?,
      );

  final String id;
  final String driverId;
  final String routeId;

  /// Where the driver said they are heading. The whole feed hangs off this.
  final String destStageId;

  final VehicleType vehicleType;
  final int seatsTotal;

  /// Seats still on offer. Not always [seatsTotal] at the start: a driver who
  /// changes direction mid-trip keeps the passengers already with them, and
  /// the new session must not sell those seats again.
  final int seatsFree;

  final bool online;
  final DateTime? wentOnlineAt;

  /// Where the driver said they are heading, resolved server-side.
  final String? destName;
  final String? destNameSw;

  /// The stage nearest the driver's last reported position, recomputed on
  /// every read. Null until there is a fix — a board that says Ubungo when
  /// the driver has reached Kibo is worse than one that says nothing.
  final String? fromName;
  final String? fromNameSw;

  String? destLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (destNameSw ?? destName) : destName;

  String? fromLabel(NjLocale locale) =>
      locale == NjLocale.sw ? (fromNameSw ?? fromName) : fromName;

  int get seatsTaken => seatsTotal - seatsFree;

  bool get isFull => seatsFree <= 0;

  @override
  bool operator ==(Object other) =>
      other is DriverSession &&
      other.id == id &&
      other.destStageId == destStageId &&
      other.seatsFree == seatsFree &&
      other.online == online;

  @override
  int get hashCode => Object.hash(id, destStageId, seatsFree, online);

  @override
  String toString() =>
      'DriverSession(${online ? 'online' : 'offline'}, '
      '$seatsFree/$seatsTotal free)';
}
