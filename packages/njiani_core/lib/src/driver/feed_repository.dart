import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver.dart';
import 'driver_repository.dart';
import 'feed_request.dart';

/// Reading the feed, and being told when to read it again.
abstract interface class FeedRepository {
  /// Everyone waiting ahead of this session, nearest first.
  ///
  /// The order comes from the server and is kept: it is by distance along the
  /// road, and the design is explicit that it is never by price — sorting a
  /// shared road by money turns it into an auction.
  Future<List<FeedRequest>> requestsFor(String sessionId);

  /// Fires when something on this route changed.
  ///
  /// A doorbell, not a window. The nudge carries a route, a vehicle type and
  /// a timestamp, because a driver has no policy to read anything else — the
  /// answer still comes from [requestsFor].
  Stream<void> nudges({required String routeId, required VehicleType vehicle});
}

/// Backed by `match_requests_for_session()` and a Realtime broadcast topic.
class SupabaseFeedRepository implements FeedRepository {
  const SupabaseFeedRepository(this._client);

  final SupabaseClient _client;

  /// Must match `public.route_feed_topic()`. A mismatch is a feed that is
  /// silently never live, so the format lives in one place on each side and
  /// a SQL assertion pins them together.
  static String topicFor({
    required String routeId,
    required VehicleType vehicle,
  }) =>
      'feed:$routeId:${vehicle.code}';

  @override
  Future<List<FeedRequest>> requestsFor(String sessionId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'match_requests_for_session',
        params: {'p_session_id': sessionId},
      );
      return [
        for (final row in rows)
          FeedRequest.fromRow(row as Map<String, dynamic>),
      ];
    } on PostgrestException catch (error) {
      throw DriverError(
        error.message.toLowerCase().contains('failed host lookup')
            ? DriverFailure.offline
            : DriverFailure.unknown,
        detail: error.message,
      );
    } catch (error) {
      // A socket that died mid-request, a DNS failure, a captive portal.
      // Reported as offline because that is what the driver can act on.
      throw DriverError(DriverFailure.offline, detail: '$error');
    }
  }

  @override
  Stream<void> nudges({
    required String routeId,
    required VehicleType vehicle,
  }) {
    final topic = topicFor(routeId: routeId, vehicle: vehicle);
    RealtimeChannel? channel;

    // Subscribed on the first listener and torn down with the last, so a
    // driver's phone is not holding a socket open for a screen nobody is
    // looking at.
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client.channel(
          topic,
          opts: const RealtimeChannelConfig(
            // Private: Realtime checks `realtime.messages` RLS before
            // delivering, and only a driver online on this route has a
            // policy for it.
            private: true,
          ),
        );
        channel!
            .onBroadcast(
              event: 'feed_changed',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      },
    );

    return controller.stream;
  }
}

/// In-memory feed, for tests and for running without a backend.
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({List<FeedRequest>? requests})
      : requests = requests ?? [];

  /// What [requestsFor] returns.
  List<FeedRequest> requests;

  /// Set to make the next read fail — the offline path.
  DriverError? failure;

  /// How many times the feed has been read, so a test can tell a poll from a
  /// nudge-driven refresh.
  int reads = 0;

  /// Session ids asked for, in order.
  final List<String> readFor = [];

  final _nudges = StreamController<void>.broadcast();

  /// Topics subscribed to, so a test can check the driver is listening to
  /// their own route and not to everything.
  final List<String> topics = [];

  @override
  Future<List<FeedRequest>> requestsFor(String sessionId) async {
    reads++;
    readFor.add(sessionId);
    if (failure != null) throw failure!;
    return List.unmodifiable(requests);
  }

  @override
  Stream<void> nudges({
    required String routeId,
    required VehicleType vehicle,
  }) {
    topics.add(
      SupabaseFeedRepository.topicFor(routeId: routeId, vehicle: vehicle),
    );
    return _nudges.stream;
  }

  /// Stands in for a passenger sending a request somewhere else entirely.
  void nudge() {
    if (!_nudges.isClosed) _nudges.add(null);
  }

  /// Closes the nudge stream.
  ///
  /// Not `@visibleForTesting`: the provider builds one of these when there is
  /// no backend and has to be able to tear it down, same as the other fakes.
  void dispose() => _nudges.close();
}
