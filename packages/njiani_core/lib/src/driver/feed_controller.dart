import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_client.dart';
import 'driver_repository.dart';
import 'driver_session.dart';
import 'feed_alert.dart';
import 'feed_repository.dart';
import 'feed_request.dart';
import 'session_controller.dart';

/// How often to re-read the feed when nothing has nudged it.
///
/// A fallback, not the mechanism. The broadcast nudge is what makes the feed
/// live; this is what makes it live again after a socket dies in a tunnel,
/// which happens. Thirty seconds because every poll is a driver's own mobile
/// data, and the design is explicit that battery and data cost them real
/// money.
///
/// Injected so tests do not wait on a real clock, and so a test that means to
/// exercise the nudge is not quietly passing on a poll.
@immutable
class FeedPollPolicy {
  const FeedPollPolicy({
    this.interval = const Duration(seconds: 30),
    this.lostLinger = const Duration(seconds: 2),
  });

  /// [Duration.zero] turns polling off entirely.
  final Duration interval;

  /// How long a lost card stays on screen under its "Taken by another
  /// driver" band before leaving.
  ///
  /// From the design, which asks for about two seconds. Long enough to read
  /// and short enough that the feed does not fill with cards nobody can
  /// take. Removing it instantly would be worse than useless: the driver
  /// tapped something, it vanished, and they never learn whether they got
  /// the seat.
  final Duration lostLinger;

  /// No polling. Refreshes happen only when something asks for one.
  static const FeedPollPolicy manual = FeedPollPolicy(interval: Duration.zero);
}

final feedPollPolicyProvider =
    Provider<FeedPollPolicy>((ref) => const FeedPollPolicy());

/// Supplies the [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client == null) {
    final fake = FakeFeedRepository();
    ref.onDispose(fake.dispose);
    return fake;
  }
  return SupabaseFeedRepository(client);
});

/// The feed, and how much to trust it.
@immutable
class FeedState {
  const FeedState({
    this.requests = const [],
    this.readAt,
    this.stale = false,
    this.loading = false,
    this.claiming = const {},
    this.lost = const {},
  });

  /// Nearest ahead first, exactly as the server returned them. The screen
  /// does not re-sort: the order is the product.
  final List<FeedRequest> requests;

  /// When the list was last read successfully.
  ///
  /// Shown to the driver once [stale] is true, because "three requests" and
  /// "three requests, as of 14:02" are different claims and only one of them
  /// is true after the connection drops.
  final DateTime? readAt;

  /// The last read failed. The list is kept — the previous answer is still
  /// the best one available — and labelled rather than blanked.
  final bool stale;

  final bool loading;

  /// Requests with a claim in flight.
  ///
  /// One tap only: the button goes to a spinner, because a driver in traffic
  /// taps twice when nothing happens, and the second tap would come back
  /// `already_taken` against their own claim.
  final Set<String> claiming;

  /// Requests another driver got first, still on screen under their band.
  final Set<String> lost;

  bool get isEmpty => requests.isEmpty;

  bool isClaiming(String requestId) => claiming.contains(requestId);

  bool wasLost(String requestId) => lost.contains(requestId);

  /// True while any claim is in flight.
  ///
  /// Every other Pickup is held during one, so two seats cannot be claimed
  /// by two taps a few hundred milliseconds apart in a two-seat vehicle.
  bool get busy => claiming.isNotEmpty;

  FeedState copyWith({
    List<FeedRequest>? requests,
    DateTime? readAt,
    bool? stale,
    bool? loading,
    Set<String>? claiming,
    Set<String>? lost,
  }) =>
      FeedState(
        requests: requests ?? this.requests,
        readAt: readAt ?? this.readAt,
        stale: stale ?? this.stale,
        loading: loading ?? this.loading,
        claiming: claiming ?? this.claiming,
        lost: lost ?? this.lost,
      );
}

/// The live feed for the driver's open session.
///
/// Rebuilds when the session changes, which covers going online, changing
/// direction and going offline — each of those is a different feed, and
/// keeping the old one on screen for even a moment would show requests the
/// driver can no longer take.
class FeedController extends AsyncNotifier<FeedState> {
  Timer? _poll;
  StreamSubscription<void>? _nudges;
  Set<String> _seen = const {};
  bool _gone = false;

  @override
  Future<FeedState> build() async {
    _gone = false;
    ref.onDispose(() => _gone = true);

    final session = ref.watch(sessionProvider).valueOrNull;

    if (session == null || !session.online) {
      _seen = const {};
      return const FeedState();
    }

    _listen(session);

    final first = await _read();
    // Nothing is "new" on the first read: the driver has just opened the
    // screen, and a chime for every card already waiting would be noise at
    // exactly the moment they are trying to read them.
    _seen = first.requests.map((r) => r.id).toSet();
    return first;
  }

  FeedRepository get _repository => ref.read(feedRepositoryProvider);

  void _listen(DriverSession session) {
    _nudges?.cancel();
    _nudges = _repository
        .nudges(routeId: session.routeId, vehicle: session.vehicleType)
        .listen(
          (_) => refresh(),
          onError: (Object error) {
            // A dead socket is not a reason to blank the feed. The poll
            // below is what recovers from it.
            debugPrint('[njiani] feed nudge: $error');
          },
        );

    final interval = ref.read(feedPollPolicyProvider).interval;
    _poll?.cancel();
    if (interval > Duration.zero) {
      _poll = Timer.periodic(interval, (_) => refresh());
    }

    ref.onDispose(() {
      _poll?.cancel();
      _nudges?.cancel();
    });
  }

  Future<FeedState> _read() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null || !session.online) return const FeedState();

    final requests = await _repository.requestsFor(session.id);
    return FeedState(requests: requests, readAt: DateTime.now());
  }

  /// Re-reads the feed. Called by a nudge, by the poll, and by the driver.
  Future<void> refresh() async {
    final current = state.valueOrNull ?? const FeedState();
    _set(current.copyWith(loading: true));

    try {
      final next = await _read();
      // A lost card is kept through a refresh until its band has been read.
      // Without this, a nudge arriving in those two seconds would yank it
      // out from under the driver and they would never learn what happened.
      _set(next.copyWith(
        requests: [
          ...next.requests,
          for (final r in current.requests)
            if (current.wasLost(r.id) && !next.requests.contains(r)) r,
        ],
        claiming: current.claiming,
        lost: current.lost,
      ));
      await _alertIfNew(next.requests);
    } on DriverError catch (error) {
      // The previous answer is still the best one available, so it is kept
      // and marked rather than thrown away. A driver in a tunnel would
      // otherwise watch their feed empty itself.
      debugPrint('[njiani] feed refresh: $error');
      _set(current.copyWith(stale: true, loading: false));
    } catch (error) {
      debugPrint('[njiani] feed refresh: $error');
      _set(current.copyWith(stale: true, loading: false));
    }
  }

  /// Takes the seat, and settles what the screen shows either way.
  ///
  /// The database decides. `accept_ride_request` is one UPDATE that can only
  /// move a request off `open` once, so a second driver tapping the same card
  /// in the same second is told `already_taken` rather than given a seat that
  /// is not there.
  ///
  /// Returns the outcome so the screen can say it out loud. The state changes
  /// here — the card leaving, the band appearing, the seat count dropping —
  /// are this method's job; the toast is the screen's.
  Future<ClaimResult> claim(FeedRequest request) async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null || !session.online) {
      return const ClaimResult(ClaimOutcome.noSession);
    }

    final before = state.valueOrNull ?? const FeedState();
    if (before.isClaiming(request.id) || before.wasLost(request.id)) {
      // Already in flight, or already settled against them. Taps on a card
      // mid-claim are the driver asking louder, not asking again.
      return const ClaimResult(ClaimOutcome.unknown);
    }

    _set(before.copyWith(claiming: {...before.claiming, request.id}));

    final result = await _repository.claim(
      requestId: request.id,
      sessionId: session.id,
    );

    final after = state.valueOrNull ?? const FeedState();
    final claiming = {...after.claiming}..remove(request.id);

    switch (result.outcome) {
      case ClaimOutcome.ok:
        // The seat count and the feed both moved server-side. Re-read both:
        // the seat bar is a promise about what the driver can still take,
        // and the claimed card is no longer claimable by anyone.
        _set(after.copyWith(claiming: claiming));
        await ref.read(sessionProvider.notifier).refresh();
        await refresh();

      case ClaimOutcome.alreadyTaken:
      case ClaimOutcome.gone:
        // Kept on screen, under its band, then removed. The driver is told
        // they lost rather than watching a card disappear.
        _set(after.copyWith(claiming: claiming, lost: {...after.lost, request.id}));
        await Future<void>.delayed(ref.read(feedPollPolicyProvider).lostLinger);
        _dropLost(request.id);

      case ClaimOutcome.seatsFull:
        // Every Pickup becomes "Seats full", which the screen reads off the
        // session rather than off this result — so it is still right after a
        // rebuild. Re-read it, because the vehicle filling up underneath the
        // driver is exactly the case where our count was wrong.
        _set(after.copyWith(claiming: claiming));
        await ref.read(sessionProvider.notifier).refresh();

      case ClaimOutcome.noSession:
        // Gone offline, or changed direction in another window. Re-reading
        // the session is what moves them off this screen: the router sends a
        // driver with no session to the picker.
        _set(after.copyWith(claiming: claiming));
        await ref.read(sessionProvider.notifier).refresh();

      case ClaimOutcome.offline:
      case ClaimOutcome.unknown:
        // The one case where nobody knows. Re-read: the seat is either
        // theirs, in which case the card is gone and the count has dropped,
        // or it is not.
        _set(after.copyWith(claiming: claiming));
        await refresh();
    }

    return result;
  }

  /// Takes a lost card off the feed once its band has been read.
  void _dropLost(String requestId) {
    final current = state.valueOrNull;
    if (current == null) return;

    _set(current.copyWith(
      requests: [for (final r in current.requests) if (r.id != requestId) r],
      lost: {...current.lost}..remove(requestId),
    ));
  }

  /// Writes state unless this notifier is gone.
  ///
  /// A claim outlives the screen: a driver who taps Pickup and immediately
  /// goes offline disposes this controller while the delay above is still
  /// running, and writing to a disposed notifier throws.
  void _set(FeedState next) {
    if (_gone) return;
    state = AsyncData(next);
  }

  /// Sounds once if anything in [requests] was not there before.
  ///
  /// Once, not once per request: three arriving together is one event to a
  /// driver, and three chimes in a second is a malfunction.
  Future<void> _alertIfNew(List<FeedRequest> requests) async {
    final ids = requests.map((r) => r.id).toSet();
    final arrived = ids.difference(_seen);
    _seen = ids;

    if (arrived.isEmpty) return;
    await ref.read(feedAlertProvider).newRequest();
  }
}

/// The driver's live feed.
final feedProvider =
    AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);
