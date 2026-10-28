import 'package:flutter/foundation.dart';

import '../locale/nj_locale.dart';

/// One direction of travel along one road.
///
/// Named `NjRoute` rather than `Route` because `Route` is Flutter's, and
/// every screen in the app imports it.
///
/// **One row per direction.** Ubungo→Kimara and Kimara→Ubungo are two
/// separate routes over the same tarmac, with reversed geometry. That is what
/// makes "ahead of me" a plain comparison along the line rather than a
/// heading vector, and it is why choosing a destination is enough to choose a
/// direction: a given stage is ahead on exactly one of the two.
@immutable
class NjRoute {
  const NjRoute({
    required this.id,
    required this.name,
    required this.nameSw,
    required this.directionLabel,
  });

  factory NjRoute.fromRow(Map<String, dynamic> row) => NjRoute(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        nameSw: row['name_sw'] as String? ?? '',
        directionLabel: row['direction_label'] as String? ?? '',
      );

  final String id;
  final String name;
  final String nameSw;

  /// `Westbound`, `Eastbound`. Not shown to a driver on its own — the
  /// destination says the direction in words they use.
  final String directionLabel;

  String label(NjLocale locale) => locale == NjLocale.sw ? nameSw : name;

  @override
  bool operator ==(Object other) => other is NjRoute && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NjRoute($directionLabel)';
}

/// A named pickup or drop point on a route.
///
/// Every pickup and destination in the MVP comes from this list: free text
/// would need a geocoder, which is out of scope (ARCHITECTURE D9).
@immutable
class Stage {
  const Stage({
    required this.id,
    required this.routeId,
    required this.name,
    required this.nameSw,
    required this.seq,
  });

  factory Stage.fromRow(Map<String, dynamic> row) => Stage(
        id: (row['stage_id'] ?? row['id']) as String,
        routeId: row['route_id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        nameSw: row['name_sw'] as String? ?? '',
        seq: (row['seq'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String routeId;
  final String name;
  final String nameSw;

  /// Position along the route, ascending in the direction of travel. The
  /// destination list is ordered by this, never alphabetically.
  final int seq;

  String label(NjLocale locale) => locale == NjLocale.sw ? nameSw : name;

  @override
  bool operator ==(Object other) => other is Stage && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Stage($name, seq $seq)';
}

/// Somewhere the driver could head for, from where they are now.
///
/// Carries its route, because that is the answer to "which direction is
/// this?" — and `go_online` needs both.
@immutable
class Destination {
  const Destination({
    required this.stage,
    required this.routeId,
    required this.directionLabel,
    required this.metresAhead,
  });

  factory Destination.fromRow(Map<String, dynamic> row) => Destination(
        stage: Stage.fromRow(row),
        routeId: row['route_id'] as String? ?? '',
        directionLabel: row['direction_label'] as String? ?? '',
        metresAhead: (row['metres_ahead'] as num?)?.toDouble() ?? 0,
      );

  final Stage stage;
  final String routeId;
  final String directionLabel;

  /// How far along the road, from the driver's position. Always positive:
  /// the query only returns what is ahead.
  final double metresAhead;

  double get kmAhead => metresAhead / 1000;

  @override
  bool operator ==(Object other) =>
      other is Destination &&
      other.stage == stage &&
      other.routeId == routeId;

  @override
  int get hashCode => Object.hash(stage, routeId);

  @override
  String toString() =>
      'Destination(${stage.name}, $directionLabel, ${metresAhead.round()}m)';
}

/// A point on the earth. Kept separate from any plugin's type so the GPS
/// package can be swapped without touching the repositories.
@immutable
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// What the server knows about where the driver is standing.
///
/// Three situations look identical from an empty destination list, and the
/// screen has to tell a driver which one they are in. See `where_am_i()`.
@immutable
class Origin {
  const Origin({
    required this.onCorridor,
    required this.routesActive,
    this.stage,
    this.metres,
  });

  factory Origin.fromRow(Map<String, dynamic> row) => Origin(
        onCorridor: row['on_corridor'] as bool? ?? false,
        routesActive: (row['routes_active'] as num?)?.toInt() ?? 0,
        stage: row['stage_id'] == null
            ? null
            : Stage(
                id: row['stage_id'] as String,
                routeId: '',
                name: row['name'] as String? ?? '',
                nameSw: row['name_sw'] as String? ?? '',
                seq: 0,
              ),
        metres: (row['metres'] as num?)?.toDouble(),
      );

  /// The nearest stage within range, or null if the driver is nowhere near
  /// one. Null is an answer, not a failure.
  final Stage? stage;

  final double? metres;

  /// True when the point is inside some active route's corridor.
  final bool onCorridor;

  /// How many routes exist at all. Zero means the database has no roads in
  /// it, which is a setup problem and not a driver one -- almost always
  /// `seed.sql` never having been run.
  final int routesActive;

  /// Nothing is configured. Nothing will work until it is.
  bool get noRoutes => routesActive == 0;

  @override
  String toString() => 'Origin(${stage?.name}, onCorridor: $onCorridor, '
      'routes: $routesActive)';
}
