import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/nj_routes.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver_session.dart';
import '../driver/feed_controller.dart';
import '../driver/feed_repository.dart';
import '../driver/feed_request.dart';
import '../driver/session_controller.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/nj_locale.dart';
import '../util/money.dart';
import '../widgets/nj_banner.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_empty_state.dart';
import '../widgets/nj_live_dot.dart';
import '../widgets/nj_route_board.dart';
import '../widgets/nj_seat_indicator.dart';
import '../widgets/nj_skeleton.dart';
import '../widgets/nj_toast.dart';

/// `dFeed` — live requests. Component C9.
///
/// The product. `match_requests_for_session()` returns the passengers who are
/// in the driver's corridor, ahead of them, and stopping at or before where
/// the driver stops. This screen shows them in the order the server returned
/// them and does not re-sort: that order is by distance along the road, and
/// the design is explicit that it is never by price, because sorting a shared
/// road by money turns it into an auction.
///
/// How it stays live, and why it is not a subscription to `ride_requests`: a
/// driver holds no read policy on that table, so there is nothing to
/// subscribe to. A trigger broadcasts a nudge carrying only a route and a
/// vehicle type, and the client answers it by re-running the matching
/// function — the live part is a doorbell, not a window. A slow poll runs
/// alongside it for the socket that dies in a tunnel.
///
/// Pickup, from C10, is settled by `accept_ride_request()` — one UPDATE that
/// can only move a request off `open` once. Two drivers tapping the same
/// passenger in the same second is the expected case on a busy road, so the
/// loser is told so rather than handed a seat that is not there. One tap, no
/// confirm dialog: the driver is in traffic.
class DriverFeedScreen extends ConsumerStatefulWidget {
  const DriverFeedScreen({super.key});

  @override
  ConsumerState<DriverFeedScreen> createState() => _DriverFeedScreenState();
}

class _DriverFeedScreenState extends ConsumerState<DriverFeedScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The socket does not survive being backgrounded on either platform, so
    // coming back is the moment this screen is most likely to be stale.
    if (state == AppLifecycleState.resumed) {
      ref.read(feedProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final session = ref.watch(sessionProvider).valueOrNull;
    final feed = ref.watch(feedProvider).valueOrNull ?? const FeedState();

    // Should be unreachable: the router sends an offline driver to the
    // direction picker. Rendered rather than asserted, because a blank screen
    // in a bajaj is worse than a redundant one.
    if (session == null || !session.online) {
      return Scaffold(
        backgroundColor: nj.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(NjSpace.xl),
              child: NjEmptyState(
                icon: Icons.wifi_tethering_off_rounded,
                message: strings.dDirectionTitle,
                action: NjButton(
                  label: strings.dPickDestination,
                  onPressed: () => context.go(NjRoutes.driverDirection),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final destination = session.destLabel(locale) ?? '';

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: Column(
          children: [
            NjRouteBoard(
              // Where the driver is, recomputed server-side on every read.
              // Falls back to the destination when there is no fix yet
              // rather than inventing an origin.
              from: session.fromLabel(locale) ?? destination,
              to: destination,
              subtitle: strings.dOnlineNow,
              actionLabel: strings.dChange,
              onAction: () => context.go(NjRoutes.driverDirection),
            ),

            _SeatBar(session: session),

            if (feed.stale && feed.readAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NjSpace.md,
                  NjSpace.md,
                  NjSpace.md,
                  0,
                ),
                // NjBanner's default tone is already danger, which is the
                // right one here: a feed that is not live is not a note.
                child: NjBanner(
                  title: strings.dFeedFrozen(_hhmm(feed.readAt!)),
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(feedProvider.notifier).refresh(),
                child: _Requests(
                  feed: feed,
                  session: session,
                  destination: destination,
                  locale: locale,
                  loading: ref.watch(feedProvider).isLoading,
                  onClaim: _claim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Takes the seat, and says out loud how it went.
  ///
  /// The controller moves the feed and the seat count; this says the sentence.
  /// A won claim with no words would leave the driver watching a card vanish
  /// and no idea whether they have a passenger.
  Future<void> _claim(FeedRequest request) async {
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final stop = request.pickupLabel(locale);

    final result = await ref.read(feedProvider.notifier).claim(request);
    if (!mounted) return;

    final message = switch (result.outcome) {
      ClaimOutcome.ok => strings.dClaimWon(stop),
      // The band on the card has already said this, for two seconds. The
      // toast would be the same sentence twice.
      ClaimOutcome.alreadyTaken || ClaimOutcome.gone => null,
      // The seat bar now reads "Every seat taken" and every Pickup has
      // become "Seats full", which says it better than a toast.
      ClaimOutcome.seatsFull => null,
      // The router is already moving them to the picker.
      ClaimOutcome.noSession => null,
      ClaimOutcome.offline => strings.dClaimChecking,
      ClaimOutcome.unknown => strings.dClaimFailed,
    };

    if (message != null) await NjToast.show(context, message);
  }

  static String _hhmm(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// Seats free, in words and in blocks.
class _SeatBar extends StatelessWidget {
  const _SeatBar({required this.session});

  final DriverSession session;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NjSpace.lg,
        vertical: NjSpace.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: nj.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session.isFull
                  ? strings.dSeatsFullLine
                  : strings.dSeatsLine(session.seatsFree, session.seatsTotal),
              style: context.njText.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: NjSpace.sm),
          NjSeatIndicator(
            total: session.seatsTotal,
            taken: session.seatsTaken,
          ),
        ],
      ),
    );
  }
}

/// The list, its empty state, and its first load.
class _Requests extends StatelessWidget {
  const _Requests({
    required this.feed,
    required this.session,
    required this.destination,
    required this.locale,
    required this.loading,
    required this.onClaim,
  });

  final FeedState feed;
  final DriverSession session;
  final String destination;
  final NjLocale locale;
  final bool loading;
  final ValueChanged<FeedRequest> onClaim;

  @override
  Widget build(BuildContext context) {
    final strings = NjStrings.of(context);

    // Only before the first answer. A refresh that is already showing cards
    // must not replace them with skeletons: the driver is reading them.
    if (loading && feed.readAt == null) {
      return ListView(
        padding: const EdgeInsets.all(NjSpace.md),
        children: const [
          NjSkeleton(height: 96),
          SizedBox(height: NjSpace.sm + 2),
          NjSkeleton(height: 96),
        ],
      );
    }

    if (feed.isEmpty) {
      // AlwaysScrollable, or pull-to-refresh has no gesture to recognise on
      // exactly the screen a driver most wants to pull.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NjSpace.xl,
              NjSpace.xxxl + NjSpace.sm,
              NjSpace.xl,
              NjSpace.xl,
            ),
            child: NjEmptyState(
              icon: Icons.schedule_rounded,
              message: strings.dFeedEmpty(destination),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NjSpace.md),
      itemCount: feed.requests.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NjSpace.sm + 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(
              left: NjSpace.xs,
              bottom: NjSpace.xs,
            ),
            child: NjLiveDot(label: strings.dFeedLive(destination)),
          );
        }
        final request = feed.requests[index - 1];
        return _RequestCard(
          request: request,
          locale: locale,
          claiming: feed.isClaiming(request.id),
          lost: feed.wasLost(request.id),
          // Full is read off the session, not off the last claim's result:
          // the session is re-read after a claim, so this stays right
          // through a rebuild and through a seat freed by a cancellation.
          seatsFull: session.isFull,
          // Every other Pickup is held during a claim. Without this, two
          // taps a few hundred milliseconds apart would both go through in
          // a vehicle with one seat left, and one of them would come back
          // seats_full after the passenger had been told they had a ride.
          busy: feed.busy,
          onClaim: () => onClaim(request),
        );
      },
    );
  }
}

/// One passenger's offer.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.locale,
    required this.claiming,
    required this.lost,
    required this.seatsFull,
    required this.busy,
    required this.onClaim,
  });

  final FeedRequest request;
  final NjLocale locale;

  /// This card's claim is in flight.
  final bool claiming;

  /// Another driver got it. Shows the band, then the card leaves.
  final bool lost;

  /// No seat left in the vehicle.
  final bool seatsFull;

  /// Some claim is in flight, on this card or another.
  final bool busy;

  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(NjSpace.md),
      decoration: BoxDecoration(
        color: nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.button),
        // The lost card is outlined in the danger colour as well as banded.
        // Colour alone is never the only signal -- the band carries the
        // words -- but together they make it unmistakable at a glance from
        // a driving seat.
        border: Border.all(color: lost ? nj.danger : nj.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  strings.dFeedAhead(
                    request.pickupLabel(locale),
                    distanceLabel(request.metresAhead, strings),
                  ),
                  style:
                      context.njText.bodySmall?.copyWith(color: nj.muted),
                ),
              ),
              const SizedBox(width: NjSpace.sm),
              // The price does not shrink and does not wrap: it is the one
              // number the driver is deciding on.
              Text(
                tsh(request.offerPrice),
                style: context.njText.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            strings.dFeedTo(request.destLabel(locale)),
            style: context.njText.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: NjSpace.md - 2),
          if (lost)
            // In place of the button, not above it. A card nobody can take
            // must not still be offering a tap.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: NjSpace.md,
                vertical: NjSpace.md - 2,
              ),
              decoration: BoxDecoration(
                // dangerSoft exists in the palette for exactly this band --
                // its doc comment names it. Tinted rather than solid: a
                // lost race is normal on a busy road, not an alarm.
                color: nj.dangerSoft,
                borderRadius: BorderRadius.circular(NjRadius.button),
              ),
              child: Text(
                strings.dClaimTaken,
                textAlign: TextAlign.center,
                style: context.njText.bodyLarge?.copyWith(
                  color: nj.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (seatsFull)
            // Filled flat and labelled with the reason, not a dimmed
            // Pickup. The design asks for both states and they say
            // different things: "not yet" against "not possible, and here
            // is why".
            NjButton(
              label: strings.dSeatsFull,
              variant: NjButtonVariant.blocked,
              onPressed: null,
            )
          else
            NjButton(
              label: claiming ? strings.dClaiming : strings.dPickup,
              // Bajaj yellow: this is the moment of commitment, and the
              // design reserves the colour for exactly that.
              variant: NjButtonVariant.bajaj,
              loading: claiming,
              onPressed: busy ? null : onClaim,
            ),
        ],
      ),
    );
  }

  /// Metres under a kilometre, kilometres above it.
  ///
  /// "900 m ahead" and "1.2 km ahead" are both things a driver can picture;
  /// "1200 m" and "0.9 km" are not.
  static String distanceLabel(int metres, NjStrings strings) => metres < 1000
      ? strings.dMetres('$metres')
      : strings.dKilometres((metres / 1000).toStringAsFixed(1));
}
