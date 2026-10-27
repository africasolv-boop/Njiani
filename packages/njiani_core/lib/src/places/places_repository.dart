import 'package:supabase_flutter/supabase_flutter.dart';

import 'place.dart';

/// Turns a point into the Well-Known Text PostGIS parses.
///
/// **Longitude first.** PostGIS reads `POINT(x y)` as `POINT(lng lat)`, and
/// swapping them puts a driver in Dar es Salaam somewhere off the coast of
/// Somalia — close enough to look plausible, far enough that nothing ever
/// matches. Written once, here, so no call site has to remember.
String wktPoint(LatLng point) => 'POINT(${point.lng} ${point.lat})';

/// Routes, stages, and what is ahead of a point on the road.
abstract interface class PlacesRepository {
  /// The stage nearest [point], for the "starting from" line.
  Future<Stage?> nearestStage(LatLng point);

  /// Everywhere the driver could head for from [point], ordered by route then
  /// by position along it.
  Future<List<Destination>> destinationsAhead(LatLng point);

  /// The same list, from a stage the driver named instead of a GPS fix.
  ///
  /// The geometry stays on the server: a `geography` column reaches the
  /// client as hex EWKB, and a client that parses that to ask a question is a
  /// client that will get it wrong.
  Future<List<Destination>> destinationsFromStage(String stageId);

  /// Every active stage, for the no-GPS fallback.
  ///
  /// The same physical place appears once per direction, so this is
  /// de-duplicated by name: a driver picking where they are standing does not
  /// care which of the two rows they touched, and seeing "Ubungo Mataa"
  /// twice in a list would just be confusing.
  Future<List<Stage>> allStages();
}

/// Backed by the `stages` table and the C7 functions.
class SupabasePlacesRepository implements PlacesRepository {
  const SupabasePlacesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Stage?> nearestStage(LatLng point) async {
    final rows = await _client.rpc<List<dynamic>>(
      'nearest_stage',
      params: {'p_point': wktPoint(point)},
    );
    if (rows.isEmpty) return null;
    return Stage.fromRow(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<Destination>> destinationsAhead(LatLng point) async {
    final rows = await _client.rpc<List<dynamic>>(
      'destinations_ahead',
      params: {'p_point': wktPoint(point)},
    );
    return [
      for (final row in rows) Destination.fromRow(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<Destination>> destinationsFromStage(String stageId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'destinations_from_stage',
      params: {'p_stage_id': stageId},
    );
    return [
      for (final row in rows) Destination.fromRow(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<Stage>> allStages() async {
    final rows = await _client
        .from('stages')
        .select('id, route_id, name, name_sw, seq')
        .eq('active', true)
        .order('seq');

    final seen = <String>{};
    final stages = <Stage>[];
    for (final row in rows) {
      final stage = Stage.fromRow(row);
      if (seen.add(stage.name)) stages.add(stage);
    }
    stages.sort((a, b) => a.name.compareTo(b.name));
    return stages;
  }
}

/// In-memory places, for tests and for running without a backend.
///
/// Seeded with the pilot corridor so the direction screen is walkable with no
/// database at all — which is the point of D16, mock data first.
class FakePlacesRepository implements PlacesRepository {
  FakePlacesRepository({List<Destination>? destinations, Stage? nearest})
      : destinations = destinations ?? defaultDestinations,
        // Assigned here, not as a field initialiser: `this.nearest` as a
        // parameter would shadow the initialiser and leave it null whenever
        // the caller did not pass one, which is almost always.
        nearest = nearest ?? ubungoMataa;

  /// What [destinationsAhead] returns, whatever point it is given.
  List<Destination> destinations;

  /// What [nearestStage] returns. Where the driver is standing — which is
  /// never one of [destinations], because you cannot head to where you are.
  Stage? nearest;

  /// The stage the fake driver is standing at.
  static const Stage ubungoMataa = Stage(
    id: 'west-1',
    routeId: westId,
    name: 'Ubungo Mataa',
    nameSw: 'Ubungo Mataa',
    seq: 1,
  );

  Object? failure;

  static const String westId = 'route-west';
  static const String eastId = 'route-east';

  /// The westbound corridor, in route order, plus the one stage that is
  /// ahead eastbound from Ubungo — so a test can tell the two directions
  /// apart without inventing a second road.
  static final List<Destination> defaultDestinations = [
    for (final (index, name) in const [
      'Shekilango',
      'Ubungo Maji',
      'Riverside',
      'Kibo',
      'Bucha',
      'Kimara Suka',
      'Kimara Korogwe',
      'Kimara Mwisho',
    ].indexed)
      Destination(
        stage: Stage(
          id: 'west-${index + 2}',
          routeId: westId,
          name: name,
          nameSw: name,
          seq: index + 2,
        ),
        routeId: westId,
        directionLabel: 'Westbound',
        metresAhead: 880.0 * (index + 1),
      ),
    const Destination(
      stage: Stage(
        id: 'east-9',
        routeId: eastId,
        name: 'Ubungo Bus Terminal',
        nameSw: 'Stendi ya Ubungo',
        seq: 9,
      ),
      routeId: eastId,
      directionLabel: 'Eastbound',
      metresAhead: 807,
    ),
  ];

  @override
  Future<Stage?> nearestStage(LatLng point) async {
    if (failure != null) throw failure!;
    return nearest;
  }

  @override
  Future<List<Destination>> destinationsAhead(LatLng point) async {
    if (failure != null) throw failure!;
    return destinations;
  }

  @override
  Future<List<Destination>> destinationsFromStage(String stageId) async {
    if (failure != null) throw failure!;
    return destinations;
  }

  @override
  Future<List<Stage>> allStages() async {
    if (failure != null) throw failure!;
    final stages = [
      ubungoMataa,
      for (final destination in destinations) destination.stage,
    ];
    final seen = <String>{};
    final unique = [for (final s in stages) if (seen.add(s.name)) s];
    unique.sort((a, b) => a.name.compareTo(b.name));
    return unique;
  }
}
