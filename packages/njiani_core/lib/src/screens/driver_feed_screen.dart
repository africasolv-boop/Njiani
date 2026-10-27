import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/nj_routes.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver_session.dart';
import '../driver/feed_controller.dart';
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
/// **Pickup is C10.** The claim has to be settled by `accept_ride_request()`,
/// with the losing driver shown "Taken by another driver", and that is its
/// own component. The button says what it is waiting for rather than
/// silently doing nothing.
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
                  destination: destination,
                  locale: locale,
                  loading: ref.watch(feedProvider).isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    required this.destination,
    required this.locale,
    required this.loading,
  });

  final FeedState feed;
  final String destination;
  final NjLocale locale;
  final bool loading;

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
        return _RequestCard(
          request: feed.requests[index - 1],
          locale: locale,
        );
      },
    );
  }
}

/// One passenger's offer.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.locale});

  final FeedRequest request;
  final NjLocale locale;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(NjSpace.md),
      decoration: BoxDecoration(
        color: nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.button),
        border: Border.all(color: nj.line),
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
          // C10 wires this to accept_ride_request(). Disabled and labelled
          // rather than present and dead: a driver tapping a button that
          // does nothing concludes the app is broken, which is worse than
          // being told what is coming.
          NjButton(
            label: strings.dPickupSoon,
            variant: NjButtonVariant.blocked,
            onPressed: null,
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
