import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver.dart';
import 'driver_repository.dart';
import 'feed_request.dart';

/// How a tap on Pickup came out.
///
/// From `accept_ride_request`, which settles the race in one UPDATE that can
/// only move a request off `open` once. Every value here is the database's
/// word: the UI never decides who won.
enum ClaimOutcome {
  /// The seat is yours.
  ok,

  /// Another driver got there first. Normal, not an error — two drivers
  /// tapping the same passenger in the same second is the expected case on a
  /// busy road.
  alreadyTaken,

  /// No seat left in the vehicle.
  seatsFull,

  /// The session ended underneath the screen — gone offline, or changed
  /// direction in another window.
  noSession,

  /// The request expired between the feed being read and the tap.
  gone,

  offline,
  unknown,
}

/// The outcome, and the seat if there is one.
@immutable
class ClaimResult {
  const ClaimResult(this.outcome, {this.seatId});

  final ClaimOutcome outcome;
  final String? seatId;

  bool get won => outcome == ClaimOutcome.ok;

  /// True when the card should leave the feed either way: somebody has it.
  bool get settled =>
      outcome == ClaimOutcome.ok ||
      outcome == ClaimOutcome.alreadyTaken ||
      outcome == ClaimOutcome.gone;

  @override
  String toString() => 'ClaimResult(${outcome.name})';
}

/// Reading the feed, and being told when to read it again.
abstract interface class FeedRepository {
  /// Everyone waiting ahead of this session, nearest first.
  ///
  /// The order comes from the server and is kept: it is by distance along the
  /// road, and the design is explicit that it is never by price — sorting a
  /// shared road by money turns it into an auction.
  Future<List<FeedRequest>> requestsFor(String sessionId);

  /// Takes the seat.
  ///
  /// One tap, no confirm dialog: the driver is in traffic, and the design is
  /// explicit that undo is Cancel on the On board tab rather than a question
  /// asked at 40 km/h.
  Future<ClaimResult> claim({
    required String requestId,
    required String sessionId,
  });

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
  Future<ClaimResult> claim({
    required String requestId,
    required String sessionId,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'accept_ride_request',
        params: {'p_request_id': requestId, 'p_session_id': sessionId},
      );
      if (rows.isEmpty) return const ClaimResult(ClaimOutcome.unknown);

      final row = rows.first as Map<String, dynamic>;
      final reason = row['reason'] as String?;

      return ClaimResult(
        switch (reason) {
          'ok' => ClaimOutcome.ok,
          'already_taken' => ClaimOutcome.alreadyTaken,
          'seats_full' => ClaimOutcome.seatsFull,
          'no_session' => ClaimOutcome.noSession,
          _ => ClaimOutcome.unknown,
        },
        seatId: row['seat_id'] as String?,
      );
    } on PostgrestException catch (error) {
      debugPrint('[njiani] claim: ${error.message}');
      return const ClaimResult(ClaimOutcome.unknown);
    } catch (error) {
      // A dropped connection mid-claim is the one case where the driver
      // genuinely does not know. Reported as offline rather than lost: the
      // feed re-reads, and the seat is either theirs or it is not.
      debugPrint('[njiani] claim: $error');
      return const ClaimResult(ClaimOutcome.offline);
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

  /// What the next claim returns. The default is a win.
  ClaimResult claimResult = const ClaimResult(ClaimOutcome.ok, seatId: 'seat-1');

  /// Requests a claim was attempted on, in order.
  final List<String> claimed = [];

  /// Run on a won claim, to model what the server did to everything else —
  /// most usefully the seat count on the session.
  void Function()? onClaim;

  /// When set, a claim waits on this before answering.
  ///
  /// Without it the in-flight state is over within a microtask, so a test
  /// cannot see the held buttons — and "every other Pickup is held during a
  /// claim" is the rule that stops two taps filling one seat twice.
  Completer<void>? claimGate;

  @override
  Future<List<FeedRequest>> requestsFor(String sessionId) async {
    reads++;
    readFor.add(sessionId);
    if (failure != null) throw failure!;
    return List.unmodifiable(requests);
  }

  @override
  Future<ClaimResult> claim({
    required String requestId,
    required String sessionId,
  }) async {
    claimed.add(requestId);
    if (claimGate != null) await claimGate!.future;
    if (claimResult.won) {
      // What the server would do: the request leaves the feed.
      requests = [for (final r in requests) if (r.id != requestId) r];
    }
    onClaim?.call();
    return claimResult;
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
