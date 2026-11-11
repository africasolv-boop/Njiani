import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../data/supabase_client.dart';
import 'request_controller.dart';
import 'seat_repository.dart';
import 'trip_seat.dart';

/// How often to re-read the seat when nothing has changed on it.
///
/// Both mechanisms are needed and they do different jobs. The subscription
/// catches a change to the seat *row* — the driver cancelling, or marking the
/// passenger aboard — within a second. The poll is what moves the ETA, and
/// there is no subscription that could: the driver's position is written to
/// `driver_sessions`, which a passenger holds no read policy on, so the only
/// way to learn the vehicle is closer is to ask `current_trip_seat()` again.
///
/// Twenty seconds because at 18 km/h that is 100 m, which is the smallest
/// movement that can change a whole-minute estimate.
@immutable
class SeatPollPolicy {
  const SeatPollPolicy({this.interval = const Duration(seconds: 20)});

  /// [Duration.zero] turns polling off entirely.
  final Duration interval;

  /// No polling. Refreshes happen only when something asks for one.
  static const SeatPollPolicy manual = SeatPollPolicy(interval: Duration.zero);
}

final seatPollPolicyProvider =
    Provider<SeatPollPolicy>((ref) => const SeatPollPolicy());

/// Supplies the [SeatRepository].
final seatRepositoryProvider = Provider<SeatRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client == null) {
    final fake = FakeSeatRepository();
    ref.onDispose(fake.dispose);
    return fake;
  }
  return SupabaseSeatRepository(client);
});

/// The seat the passenger holds, or null.
///
/// Rider app only. Null is a state, not an error: it is what the router reads
/// to decide whether the passenger belongs on the matched screen at all.
class SeatController extends AsyncNotifier<TripSeat?> {
  Timer? _poll;
  StreamSubscription<void>? _changes;
  bool _gone = false;

  @override
  Future<TripSeat?> build() async {
    _gone = false;
    ref.onDispose(() {
      _gone = true;
      _poll?.cancel();
      _changes?.cancel();
    });

    final signedIn = ref.watch(authProvider).step == AuthStep.signedIn;
    if (!signedIn) return null;

    _listen();
    return _repository.current();
  }

  SeatRepository get _repository => ref.read(seatRepositoryProvider);

  void _listen() {
    _changes?.cancel();
    _changes = _repository.changes().listen(
          (_) => refresh(),
          onError: (Object error) {
            // A dead socket is not a reason to blank a trust panel the
            // passenger is reading a plate off. The poll recovers from it.
            debugPrint('[njiani] seat changes: $error');
          },
        );

    final interval = ref.read(seatPollPolicyProvider).interval;
    _poll?.cancel();
    if (interval > Duration.zero) {
      _poll = Timer.periodic(interval, (_) => refresh());
    }
  }

  /// Re-reads the seat.
  Future<void> refresh() async {
    try {
      final next = await _repository.current();
      if (_gone) return;
      state = AsyncData(next);
    } catch (error) {
      // Kept, not blanked. The previous answer still has the right plate on
      // it, and a passenger standing at a stage with a bajaj pulling up needs
      // that more than they need an accurate ETA.
      debugPrint('[njiani] could not read the seat: $error');
      if (_gone || state.hasValue) return;
      state = const AsyncData(null);
    }
  }

  /// Gives the seat up.
  ///
  /// Also clears the request the seat came from, because the server does:
  /// `cancel_my_seat` marks the request cancelled rather than reopening it,
  /// so leaving the waiting panel's copy in place would show a passenger
  /// looking for a driver they have just sent away.
  Future<void> cancel() async {
    await _repository.cancel();
    if (!_gone) state = const AsyncData(null);
    await ref.read(requestProvider.notifier).refresh();
  }
}

/// The passenger's claimed seat.
final seatProvider =
    AsyncNotifierProvider<SeatController, TripSeat?>(SeatController.new);
