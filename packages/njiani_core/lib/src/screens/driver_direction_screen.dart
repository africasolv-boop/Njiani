import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/nj_routes.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver_controller.dart';
import '../driver/driver_location.dart';
import '../driver/driver_repository.dart';
import '../driver/driver_session.dart';
import '../driver/session_controller.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/nj_locale.dart';
import '../places/place.dart';
import '../util/redact.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_sheet.dart';
import '../widgets/nj_skeleton.dart';
import '../widgets/nj_where_row.dart';

/// `dDirection` — pick a direction. Component C7.
///
/// The screen that makes Njiani not a ride-hailing app. A driver declares
/// where they are going **before** seeing a single request, and the feed at
/// C9 is derived from that declaration rather than from a radius around them.
///
/// Two things are doing more work than they look like they are:
///
///   * **Choosing a destination chooses the direction.** Ubungo→Kimara and
///     Kimara→Ubungo are two route rows over the same tarmac, so a driver's
///     point sits in both corridors — but any given stage is ahead on exactly
///     one of them. No compass, no extra question.
///   * **No GPS is a supported state, not an error.** A driver between
///     buildings at Ubungo may never get a fix, so the screen says why it is
///     asking, then offers the stage list. Every message below names the way
///     round as well as the problem.
class DriverDirectionScreen extends ConsumerStatefulWidget {
  const DriverDirectionScreen({super.key});

  @override
  ConsumerState<DriverDirectionScreen> createState() =>
      _DriverDirectionScreenState();
}

class _DriverDirectionScreenState extends ConsumerState<DriverDirectionScreen> {
  /// The stage the driver named by hand, or null to ask the device.
  Stage? _from;

  Destination? _chosen;
  bool _busy = false;
  DriverError? _error;

  Future<void> _pickStartStage() async {
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final stages = await ref.read(placesRepositoryProvider).allStages();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Stage>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NjSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.dStagesTitle, style: context.njText.headlineSmall),
            const SizedBox(height: NjSpace.md),
            // Bounded, and scrolling inside that bound.
            //
            // `shrinkWrap` inside a MainAxisSize.min column sizes the list to
            // its content, which for a corridor with ten stages runs off the
            // bottom of the sheet -- and the entries past the edge are not
            // just hidden, they cannot be tapped. Half the screen, scrolling,
            // keeps every stage reachable on the smallest phone and leaves
            // the sheet looking like a sheet.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              // Its own Material, because NjSheet's background is a plain
              // decorated box: without one a ListTile paints its ink splash
              // behind that box and a tap shows no feedback at all.
              child: Material(
                type: MaterialType.transparency,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stages.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(stages[index].label(locale)),
                    onTap: () => Navigator.of(context).pop(stages[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _from = picked;
      // The old choice was somewhere ahead of somewhere else.
      _chosen = null;
    });
  }

  Future<void> _goOnline(DirectionOptions options) async {
    final destination = _chosen;
    if (destination == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).goOnline(
            routeId: destination.routeId,
            destStageId: destination.stage.id,
            position: options.point,
            fromStageId: options.fromStageId,
          );
      // No navigation here. The router reads the open session and moves to
      // the feed, the same way the C6 gate works.
    } on DriverError catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = DriverError(DriverFailure.unknown, detail: '$error'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goOffline() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).goOffline();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final options = ref.watch(directionOptionsProvider(_from));
    final session = ref.watch(sessionProvider).valueOrNull;
    final seats = ref.watch(driverProvider).valueOrNull?.seats ?? 0;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: [
            if (session != null) ...[
              _OnlineBanner(session: session, onGoOffline: _busy ? null : _goOffline),
              const SizedBox(height: NjSpace.lg),
            ],

            Text(strings.dDirectionTitle, style: context.njText.headlineLarge),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.dDirectionSubtitle,
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.lg),
            ...switch (options) {
              AsyncLoading() => [
                  NjWhereRow(
                    fromLabel: strings.dStartingFrom,
                    fromValue: strings.dFindingYou,
                  ),
                  const SizedBox(height: NjSpace.lg),
                  const NjSkeleton(height: 52),
                  const SizedBox(height: NjSpace.sm),
                  const NjSkeleton(height: 52),
                ],
              AsyncError(:final error) => [
                  _Problem(
                    message: strings.errUnknown,
                    detail: '$error',
                    onRetry: _retryLocation,
                    retryLabel: strings.dTryLocationAgain,
                    onPickStage: _pickStartStage,
                    pickLabel: strings.dPickStartStage,
                  ),
                ],
              AsyncData(:final value) => _body(value, locale, strings, seats),
              _ => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }

  void _retryLocation() {
    setState(() => _from = null);
    ref.invalidate(directionOptionsProvider(null));
  }

  List<Widget> _body(
    DirectionOptions options,
    NjLocale locale,
    NjStrings strings,
    int seats,
  ) {
    final nj = context.nj;

    // No fix, and no stage named yet. Say why, then offer the way round.
    if (!options.hasOrigin) {
      return [
        _Problem(
          message: _locationMessage(options.problem, strings),
          onRetry: options.problem == LocationProblem.deniedForever
              ? null
              : _retryLocation,
          retryLabel: strings.dTryLocationAgain,
          onPickStage: _pickStartStage,
          pickLabel: strings.dPickStartStage,
        ),
      ];
    }

    final grouped = options.byDirection;

    return [
      NjWhereRow(
        fromLabel: options.located
            ? strings.dStartingFrom
            : strings.dStartingFromPicked,
        fromValue: options.from?.label(locale) ?? '',
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: _pickStartStage,
          child: Text(strings.dChangeStartStage),
        ),
      ),

      if (grouped.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: NjSpace.lg),
          child: Text(
            strings.dNoDestinations,
            style: context.njText.bodyMedium?.copyWith(color: nj.muted),
          ),
        ),

      for (final entry in grouped.entries) ...[
        const SizedBox(height: NjSpace.lg),
        // Headed by where the road ends, not by "Westbound". A driver knows
        // Kimara Mwisho; nobody at a stage thinks in compass points.
        Text(
          strings.dHeadingWest(entry.value.last.stage.label(locale)),
          style: context.njText.bodySmall?.copyWith(
            color: nj.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: NjSpace.sm),
        _DestinationGrid(
          destinations: entry.value,
          chosen: _chosen,
          locale: locale,
          onPick: _busy
              ? null
              : (destination) => setState(() => _chosen = destination),
        ),
      ],

      const SizedBox(height: NjSpace.lg),
      NjCard(
        child: Text.rich(
          TextSpan(
            style: context.njText.bodySmall?.copyWith(color: nj.muted),
            children: [
              TextSpan(
                text: strings.dSeatsFree(seatsOnOffer(seats)),
                style: TextStyle(
                  color: nj.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: '  '),
              TextSpan(text: strings.dSeatsNote),
            ],
          ),
        ),
      ),

      if (_error != null) ...[
        const SizedBox(height: NjSpace.md),
        Text(
          driverFailureMessage(_error!.failure, strings),
          style: context.njText.bodySmall?.copyWith(color: nj.danger),
        ),
        if (kDebugMode && _error!.detail != null)
          Text(
            redactSecrets(_error!.detail!),
            style: context.njText.bodySmall
                ?.copyWith(color: nj.muted, fontSize: 11.5),
          ),
      ],

      // The component gallery used to be reachable from the landing screen,
      // which an online driver no longer sees -- C9 sends them to the feed
      // instead. Parked here, in debug builds only: every driver passes
      // through this screen, and it is not the product's hot path.
      if (kDebugMode) ...[
        const SizedBox(height: NjSpace.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => context.push(NjRoutes.gallery),
            child: Text(strings.openComponentGallery),
          ),
        ),
      ],

      const SizedBox(height: NjSpace.lg),
      _GoOnlineButton(
        chosen: _chosen,
        locale: locale,
        busy: _busy,
        changing: ref.watch(sessionProvider).valueOrNull != null,
        onPressed: () => _goOnline(options),
      ),
    ];
  }

  /// Seats the next session will offer. Falls back to the driver's total.
  int seatsOnOffer(int total) =>
      ref.watch(sessionProvider).valueOrNull?.seatsFree ?? total;

  static String _locationMessage(LocationProblem? problem, NjStrings strings) =>
      switch (problem) {
        LocationProblem.denied => strings.dLocationDenied,
        LocationProblem.deniedForever => strings.dLocationBlocked,
        LocationProblem.serviceOff => strings.dLocationOff,
        LocationProblem.timedOut => strings.dLocationSlow,
        LocationProblem.unknown || null => strings.dLocationSlow,
      };
}

/// The banner shown when a session is already open.
class _OnlineBanner extends StatelessWidget {
  const _OnlineBanner({required this.session, required this.onGoOffline});

  final DriverSession session;
  final VoidCallback? onGoOffline;

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
        color: nj.bajaj,
        borderRadius: BorderRadius.circular(NjRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.dOnlineNow,
                  style: context.njText.bodyMedium?.copyWith(
                    color: nj.bajajInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  strings.dSeatsFree(session.seatsFree),
                  style: context.njText.bodySmall
                      ?.copyWith(color: nj.bajajInk.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onGoOffline,
            child: Text(
              strings.dGoOffline,
              style: TextStyle(color: nj.bajajInk, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-column grid of destinations.
class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({
    required this.destinations,
    required this.chosen,
    required this.locale,
    required this.onPick,
  });

  final List<Destination> destinations;
  final Destination? chosen;
  final NjLocale locale;
  final ValueChanged<Destination>? onPick;

  @override
  Widget build(BuildContext context) {
    // Rows of two Expanded tiles, rather than a Wrap or a LayoutBuilder.
    //
    // NjScreenBody wraps its column in an IntrinsicHeight, which asks its
    // children for a dry layout -- and a LayoutBuilder cannot give one, so
    // sizing the tiles from the incoming constraints threw
    // `_RenderLayoutBuilder does not support dry layout` the moment this
    // screen was pumped. Expanded inside a Row needs no such question asked.
    final rows = <Widget>[];
    for (var i = 0; i < destinations.length; i += 2) {
      final pair = destinations.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : NjSpace.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final destination in pair) ...[
                  if (destination != pair.first)
                    const SizedBox(width: NjSpace.sm),
                  Expanded(
                    child: _DestinationTile(
                      destination: destination,
                      selected: destination == chosen,
                      locale: locale,
                      onTap: onPick == null
                          ? null
                          : () => onPick!(destination),
                    ),
                  ),
                ],
                // An odd count leaves the last tile half width rather than
                // stretched across the row, so the grid stays a grid.
                if (pair.length == 1) ...[
                  const SizedBox(width: NjSpace.sm),
                  const Spacer(),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.locale,
    required this.onTap,
  });

  final Destination destination;
  final bool selected;
  final NjLocale locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? nj.bajaj : nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.input),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NjRadius.input),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.all(NjSpace.md - 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NjRadius.input),
              border: Border.all(
                color: selected ? nj.bajaj : nj.line,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  destination.stage.label(locale),
                  style: context.njText.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? nj.bajajInk : nj.ink,
                  ),
                ),
                Text(
                  strings.dKmAway(destination.kmAhead.toStringAsFixed(1)),
                  style: context.njText.bodySmall?.copyWith(
                    fontSize: 12,
                    color: selected
                        ? nj.bajajInk.withValues(alpha: 0.75)
                        : nj.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The primary action, which names the destination.
///
/// Disabled until something is chosen rather than hidden: the driver can see
/// what they are working towards, and a mis-tap is visible in the label
/// before it costs anything.
class _GoOnlineButton extends StatelessWidget {
  const _GoOnlineButton({
    required this.chosen,
    required this.locale,
    required this.busy,
    required this.changing,
    required this.onPressed,
  });

  final Destination? chosen;
  final NjLocale locale;
  final bool busy;
  final bool changing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = NjStrings.of(context);
    final destination = chosen;

    final label = switch ((busy, destination)) {
      (true, _) => strings.dGoingOnline,
      (false, null) => strings.dPickDestination,
      (false, final picked?) => changing
          ? strings.dChangeHeading(picked.stage.label(locale))
          : strings.dGoOnline(picked.stage.label(locale)),
    };

    return NjButton(
      label: label,
      // Bajaj yellow, as the design has it: going online is the one action
      // on this screen that changes what the world can see of the driver.
      variant: NjButtonVariant.bajaj,
      loading: busy,
      onPressed: destination == null || busy ? null : onPressed,
    );
  }
}

/// A location problem, with the way round it.
class _Problem extends StatelessWidget {
  const _Problem({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
    required this.onPickStage,
    required this.pickLabel,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback onPickStage;
  final String pickLabel;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NjCard(
          child: Text(
            message,
            style: context.njText.bodyMedium?.copyWith(color: nj.muted),
          ),
        ),
        if (kDebugMode && detail != null)
          Padding(
            padding: const EdgeInsets.only(top: NjSpace.sm),
            child: Text(
              redactSecrets(detail!),
              style: context.njText.bodySmall
                  ?.copyWith(color: nj.muted, fontSize: 11.5),
            ),
          ),
        const SizedBox(height: NjSpace.lg),
        NjButton(label: pickLabel, onPressed: onPickStage),
        if (onRetry != null) ...[
          const SizedBox(height: NjSpace.sm + 2),
          NjButton(
            label: retryLabel,
            variant: NjButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
