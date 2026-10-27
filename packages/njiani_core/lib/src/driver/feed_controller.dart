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
  const FeedPollPolicy({this.interval = const Duration(seconds: 30)});

  /// [Duration.zero] turns polling off entirely.
  final Duration interval;

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

  bool get isEmpty => requests.isEmpty;

  FeedState copyWith({
    List<FeedRequest>? requests,
    DateTime? readAt,
    bool? stale,
    bool? loading,
  }) =>
      FeedState(
        requests: requests ?? this.requests,
        readAt: readAt ?? this.readAt,
        stale: stale ?? this.stale,
        loading: loading ?? this.loading,
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

  @override
  Future<FeedState> build() async {
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
    state = AsyncData(current.copyWith(loading: true));

    try {
      final next = await _read();
      state = AsyncData(next);
      await _alertIfNew(next.requests);
    } on DriverError catch (error) {
      // The previous answer is still the best one available, so it is kept
      // and marked rather than thrown away. A driver in a tunnel would
      // otherwise watch their feed empty itself.
      debugPrint('[njiani] feed refresh: $error');
      state = AsyncData(current.copyWith(stale: true, loading: false));
    } catch (error) {
      debugPrint('[njiani] feed refresh: $error');
      state = AsyncData(current.copyWith(stale: true, loading: false));
    }
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
