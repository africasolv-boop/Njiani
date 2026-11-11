import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/nj_locale.dart';
import '../rider/seat_controller.dart';
import '../rider/trip_seat.dart';
import '../util/money.dart';
import '../util/support_call.dart';
import '../widgets/nj_approach_band.dart';
import '../widgets/nj_avatar.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_colour_dot.dart';
import '../widgets/nj_plate.dart';
import '../widgets/nj_toast.dart';
import 'settling_screen.dart';
import 'vehicle_words.dart';

/// `pMatched` — a driver is coming. Component C10.
///
/// The moment `accept_ride_request()` returned `ok`. Everything on this
/// screen comes from one function, `current_trip_seat()`, and that function is
/// the only way a passenger ever reads a driver's name, plate or phone
/// number: there is no read policy that would let them query `drivers` or
/// `profiles`, and the reveal is scoped in SQL to a seat in a live state and
/// to that seat's two parties.
///
/// What the screen is for, in order of what a passenger standing at the road
/// actually needs:
///
/// 1. **The plate**, larger than the driver's name. It is the trust anchor —
///    a passenger verifies the bajaj that pulls up by reading its plate, and
///    the design is explicit that it outranks the name.
/// 2. **The colour and vehicle**, as a word and as the colour itself, for
///    picking the right bajaj out of four parked together.
/// 3. **The price**, which was fixed in the database at the moment of the
///    claim and cannot move.
/// 4. **The number**, so the two can find each other when the sketch above
///    is not enough. Dialler, not a call: the passenger presses the green
///    button.
/// 5. **Cancel**, free until the driver arrives, and the button says so.
///
/// The ETA is Haversine over 18 km/h — D8, until C14 puts a self-hosted OSRM
/// behind it — and it is never shown in seconds. A straight line across Dar
/// es Salaam traffic cannot carry that precision, and a countdown that is
/// wrong to the second is worse than a minute that is honestly approximate.
class MatchedScreen extends ConsumerStatefulWidget {
  const MatchedScreen({super.key});

  @override
  ConsumerState<MatchedScreen> createState() => _MatchedScreenState();
}

class _MatchedScreenState extends ConsumerState<MatchedScreen> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final seat = ref.watch(seatProvider).valueOrNull;

    // Should be unreachable: the router sends a passenger with no live seat
    // back to the request screen. Rendered rather than asserted — the seat
    // disappearing underneath this screen is exactly what happens when the
    // driver cancels, and a frame of spinner is better than a frame of
    // crash.
    if (seat == null || !seat.isLive) return const SettlingScreen();

    return Scaffold(
      backgroundColor: nj.bg,
      body: Column(
        children: [
          NjApproachBand(
            progress: NjApproachBand.progressFor(seat.metresAway),
            arrived: seat.hasArrived,
          ),
          Expanded(
            child: Container(
              // Overlaps the band, as the design does, so the sheet reads as
              // sitting on top of the road rather than beside it.
              transform: Matrix4.translationValues(0, -22, 0),
              decoration: BoxDecoration(
                color: nj.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(NjRadius.sheet),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    NjSpace.lg,
                    NjSpace.md,
                    NjSpace.lg,
                    NjSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: nj.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: NjSpace.md + 2),
                      _Headline(seat: seat),
                      const SizedBox(height: NjSpace.md + 2),
                      _DriverCard(seat: seat),
                      const SizedBox(height: NjSpace.md),
                      _Actions(
                        seat: seat,
                        cancelling: _cancelling,
                        onCall: () => dialNumber(context, seat.driverPhone),
                        onCancel: _cancel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gives the seat up.
  ///
  /// Free until the driver arrives, so there is no confirm dialog: the cost
  /// of a mis-tap is asking again, and a passenger whose plans changed should
  /// not have to argue with a modal while a bajaj is on its way.
  Future<void> _cancel() async {
    final strings = NjStrings.of(context);
    setState(() => _cancelling = true);

    String? problem;
    try {
      await ref.read(seatProvider.notifier).cancel();
      // No toast on success: the screen is gone, replaced by the request
      // screen, which is itself the answer.
    } catch (error) {
      debugPrint('[njiani] could not cancel the seat: $error');
      problem = strings.pCancelFailed;
    }

    if (!mounted) return;
    // The spinner stops before the toast, not after it. Clearing the flag in
    // a `finally` after an awaited toast left the button spinning for the
    // toast's whole two and a half seconds, which reads as a cancel still
    // going through -- the opposite of what the toast says.
    setState(() => _cancelling = false);
    if (problem != null) await NjToast.show(context, problem);
  }
}

/// How long, and where to stand.
class _Headline extends StatelessWidget {
  const _Headline({required this.seat});

  final TripSeat seat;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);

    final minutes = seat.etaMinutes;
    final stop = seat.pickupLabel(locale);

    final headline = seat.hasArrived
        ? strings.pMatchedHere(njVehicleWord(seat.vehicleType, strings))
        // No fix from the driver yet means no distance to divide, and the
        // honest sentence rather than a guessed number.
        : minutes == null
            ? strings.pMatchedOnTheWay
            : strings.pMatchedArriving(minutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: context.njText.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stop == null || stop.isEmpty
              ? strings.pMatchedWaitHere
              : strings.pMatchedWaitAt(stop),
          style: context.njText.bodySmall?.copyWith(color: nj.muted),
        ),
      ],
    );
  }
}

/// Who is coming, in what, for how much.
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.seat});

  final TripSeat seat;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(NjSpace.md),
      decoration: BoxDecoration(
        color: nj.surfaceAlt,
        borderRadius: BorderRadius.circular(NjRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NjAvatar(name: seat.driverName),
              const SizedBox(width: NjSpace.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seat.driverName,
                      style: context.njText.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      // Null rating is not 5.0. A made-up score on a
                      // driver's first trip is a lie a passenger acts on.
                      seat.rating == null
                          ? strings.pDriverNew
                          : strings.pDriverRating(
                              seat.rating!.toStringAsFixed(1),
                              seat.tripsCount,
                            ),
                      style:
                          context.njText.bodySmall?.copyWith(color: nj.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NjSpace.md - 2),
          Row(
            children: [
              // The plate does not shrink and does not wrap: a half-rendered
              // plate is worse than useless for identifying a vehicle, so
              // the sibling is the flexible one.
              NjPlateBadge(plate: seat.plate),
              const SizedBox(width: NjSpace.sm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NjColourDot(colour: seat.colour),
                    const SizedBox(width: NjSpace.xs),
                    Flexible(
                      child: Text(
                        strings.pVehicleColour(
                          njColourLabel(seat.colour, strings),
                          njVehicleWord(seat.vehicleType, strings),
                        ),
                        textAlign: TextAlign.end,
                        style: context.njText.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NjSpace.sm + 2),
          // Who else is in the vehicle. The whole product is a shared seat,
          // so arriving to find two strangers in the bajaj must not be a
          // surprise sprung at the kerb.
          if (seat.othersAboard > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                strings.pSharingWith(seat.othersAboard),
                style: context.njText.bodySmall?.copyWith(color: nj.muted),
              ),
            ),
          Text.rich(
            TextSpan(
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
              children: [
                TextSpan(text: '${strings.pPriceAgreedLabel} '),
                TextSpan(
                  text: tsh(seat.price),
                  style: context.njText.bodySmall?.copyWith(
                    color: nj.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Call, and cancel while cancelling is still free.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.seat,
    required this.cancelling,
    required this.onCall,
    required this.onCancel,
  });

  final TripSeat seat;
  final bool cancelling;
  final VoidCallback onCall;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (seat.hasPhone)
          NjButton(
            // First name only. "Call Juma Mwinyi" is a form field; "Call
            // Juma" is what the passenger is about to do.
            label: strings.pCallDriver(_firstName(seat.driverName)),
            variant: NjButtonVariant.ghost,
            onPressed: onCall,
          )
        else
          // The profile carries no number. Said plainly, rather than a
          // button that opens an empty dialler.
          Text(
            strings.pNoDriverPhone,
            textAlign: TextAlign.center,
            style: context.njText.bodySmall?.copyWith(color: nj.muted),
          ),
        const SizedBox(height: NjSpace.sm + 2),
        if (seat.hasArrived)
          // The claimed-to-aboard transition and the trip screen are C11, so
          // this says what it is waiting for rather than doing nothing. The
          // design replaces Cancel with it on arrival, which is right:
          // cancelling is free *until* the driver arrives, and the button
          // disappearing is how the passenger learns that.
          NjButton(
            label: strings.pOnBoardSoon,
            variant: NjButtonVariant.blocked,
            onPressed: null,
          )
        else
          NjButton(
            label: cancelling ? strings.pCancelling : strings.pCancelFree,
            variant: NjButtonVariant.dangerGhost,
            loading: cancelling,
            onPressed: cancelling ? null : onCancel,
          ),
      ],
    );
  }

  static String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
