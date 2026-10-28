import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_colors.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver.dart';
import '../driver/session_controller.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/nj_locale.dart';
import '../places/place.dart';
import '../rider/request_controller.dart';
import '../rider/request_repository.dart';
import '../rider/ride_request.dart';
import '../util/money.dart';
import '../util/redact.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_choice_chips.dart';
import '../widgets/nj_dev_tools.dart';
import '../widgets/nj_hint.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_segmented.dart';
import '../widgets/nj_sheet.dart';
import '../widgets/nj_skeleton.dart';
import '../widgets/nj_text_field.dart';
import '../widgets/nj_where_row.dart';

/// `pHome` — request a ride. Component C8.
///
/// The passenger's whole job in one screen: where they are going, in what,
/// for how much.
///
/// **The price is theirs.** A band is a hint and never a rule — an offer
/// below it sends with a warning and is not blocked (ARCHITECTURE §7).
/// Rejected offers reveal the floor faster than accepted ones do, which is
/// why an unmatched request is kept rather than deleted.
///
/// Pickup and destination come from the stage list, not from free text:
/// addresses would need a geocoder, which is out of scope (D9). The same two
/// functions answer it as answer the driver's direction picker — a passenger
/// choosing a destination and a driver choosing a heading are the same
/// problem seen from two seats.
class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _priceController = TextEditingController();

  /// A pickup stage the passenger named, or null to ask the device.
  Stage? _from;

  Destination? _destination;
  VehicleType _vehicle = VehicleType.bajaj;
  bool _sending = false;
  RequestFailure? _failure;
  String? _failureDetail;

  /// Ticks the expiry countdown while a request is waiting.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // One second, and only while something is actually counting down. A
    // passenger watching the clock run out is the whole point of showing it.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(requestProvider).valueOrNull != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _priceController.dispose();
    super.dispose();
  }

  int? get _price {
    final digits = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  Future<void> _pickPickupStage() async {
    final picked = await _pickStage();
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked;
      // Everywhere was "ahead of" somewhere else.
      _destination = null;
    });
  }

  Future<Stage?> _pickStage() async {
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final stages = await ref.read(placesRepositoryProvider).allStages();
    if (!mounted) return null;

    return _sheet<Stage>(
      title: strings.pChoosePickup,
      items: stages,
      label: (stage) => stage.label(locale),
    );
  }

  Future<void> _pickDestination(DirectionOptions options) async {
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);

    final picked = await _sheet<Destination>(
      title: strings.pChooseDestination,
      items: options.destinations,
      // The direction is in the list, not a separate question: a stage is
      // ahead on exactly one of the two routes over this road.
      label: (destination) => '${destination.stage.label(locale)}  ·  '
          '${destination.kmAhead.toStringAsFixed(1)} km',
    );

    if (picked == null || !mounted) return;
    setState(() => _destination = picked);
  }

  /// A bounded, scrolling list in a sheet.
  ///
  /// Bounded because an unbounded `shrinkWrap` list inside a `MainAxisSize.min`
  /// column runs off the bottom of the sheet, and entries past the edge are
  /// not merely hidden — they cannot be tapped.
  Future<T?> _sheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => NjSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.njText.headlineSmall),
              const SizedBox(height: NjSpace.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                // Its own Material: NjSheet's background is a plain decorated
                // box, so a ListTile would paint its ink splash behind it and
                // a tap would show no feedback.
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(label(items[index])),
                      onTap: () => Navigator.of(context).pop(items[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _send(DirectionOptions options) async {
    final destination = _destination;
    final price = _price;
    final pickupId = options.from?.id ?? options.fromStageId;
    if (destination == null || price == null || pickupId == null) return;

    setState(() {
      _sending = true;
      _failure = null;
      _failureDetail = null;
    });

    try {
      await ref.read(requestProvider.notifier).send(
            pickupStageId: pickupId,
            destStageId: destination.stage.id,
            vehicle: _vehicle,
            offerPrice: price,
          );
      // The screen reads `requestProvider` and swaps itself for the waiting
      // panel. No navigation: there is one screen here, in two states.
    } on RequestError catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.failure;
        _failureDetail = error.detail;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = RequestFailure.unknown;
        _failureDetail = '$error';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _sending = true);
    try {
      await ref.read(requestProvider.notifier).cancel();
      if (mounted) _priceController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final waiting = ref.watch(requestProvider).valueOrNull;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: waiting == null ? _form() : _waiting(waiting),
        ),
      ),
    );
  }

  // =========================================================================
  // Waiting
  // =========================================================================
  List<Widget> _waiting(RideRequest request) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final left = request.remaining(DateTime.now());
    final expired = left == Duration.zero;

    return [
      const SizedBox(height: NjSpace.xxl),
      Text(
        expired ? strings.pExpired : strings.pWaitingTitle,
        style: context.njText.headlineLarge,
      ),
      const SizedBox(height: NjSpace.sm),
      if (!expired)
        Text(
          strings.pWaitingBody,
          style: context.njText.bodyMedium?.copyWith(color: nj.muted),
        ),

      const SizedBox(height: NjSpace.xl),
      NjCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NjWhereRow(
              fromLabel: strings.pPickupPicked,
              fromValue: request.pickupLabel(locale) ?? '',
              toLabel: strings.pGoingTo,
              toValue: request.destLabel(locale) ?? '',
            ),
            const SizedBox(height: NjSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.vehicleType == VehicleType.boda
                        ? strings.pSeatsBoda
                        : strings.pSeatsBajaj,
                    style: context.njText.bodySmall?.copyWith(color: nj.muted),
                  ),
                ),
                Text(
                  tsh(request.offerPrice),
                  style: context.njText.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),

      if (!expired) ...[
        const SizedBox(height: NjSpace.md),
        Center(
          child: Text(
            strings.pExpiresIn(_mmss(left)),
            style: context.njText.bodyMedium?.copyWith(
              color: left.inSeconds <= 60 ? nj.danger : nj.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],

      const SizedBox(height: NjSpace.xl),
      NjButton(
        label: expired ? strings.pSendAnother : strings.pCancelRequest,
        variant: expired ? NjButtonVariant.primary : NjButtonVariant.ghost,
        loading: _sending,
        onPressed: _sending ? null : _cancel,
      ),
    ];
  }

  /// `9:58`, counting down.
  static String _mmss(Duration left) =>
      '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';

  // =========================================================================
  // The form
  // =========================================================================
  List<Widget> _form() {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final locale = NjLocale.of(context);
    final options = ref.watch(pickupOptionsProvider(_from));

    return [
      Text(strings.pRequestTitle, style: context.njText.headlineLarge),
      const SizedBox(height: NjSpace.lg),
      ...switch (options) {
        AsyncLoading() => const [
            NjSkeleton(height: 64),
            SizedBox(height: NjSpace.md),
            NjSkeleton(height: 52),
          ],
        AsyncError() => [
            _problem(strings.errRequestFailed, null),
            const SizedBox(height: NjSpace.lg),
            NjButton(
              label: strings.pChoosePickup,
              onPressed: _pickPickupStage,
            ),
          ],
        AsyncData(:final value) => _formFor(value, locale, strings, nj),
        _ => const <Widget>[],
      },
    ];
  }

  List<Widget> _formFor(
    DirectionOptions options,
    NjLocale locale,
    NjStrings strings,
    NjColors nj,
  ) {
    final pickupId = options.from?.id ?? options.fromStageId;

    // No fix, no named stage, or nowhere to go from where they are. The
    // driver's picker explains each of these at length; a passenger needs
    // one sentence and the list.
    if (pickupId == null || options.destinations.isEmpty) {
      return [
        NjCard(
          child: Text(
            options.origin?.noRoutes ?? false
                ? strings.dNoRoutesConfigured
                : strings.dOffCorridor,
            style: context.njText.bodyMedium?.copyWith(color: nj.muted),
          ),
        ),
        if (!(options.origin?.noRoutes ?? false)) ...[
          const SizedBox(height: NjSpace.md),
          NjButton(label: strings.pChoosePickup, onPressed: _pickPickupStage),
        ],
      ];
    }

    final destination = _destination;
    final band = destination == null
        ? const AsyncData<PriceBand?>(null)
        : ref.watch(priceBandProvider(BandKey(
            fromStageId: pickupId,
            toStageId: destination.stage.id,
            vehicle: _vehicle,
          )));
    final bandValue = band.valueOrNull;
    final price = _price;
    final below = price != null && (bandValue?.isBelow(price) ?? false);

    return [
      NjWhereRow(
        fromLabel: options.located
            ? strings.pPickupLabel
            : strings.pPickupPicked,
        fromValue: options.from?.label(locale) ?? '',
        toLabel: strings.pGoingTo,
        toChild: _DestinationButton(
          label: destination?.stage.label(locale) ??
              strings.pChooseDestination,
          chosen: destination != null,
          onTap: _sending ? null : () => _pickDestination(options),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: _sending ? null : _pickPickupStage,
          child: Text(strings.dChangeStartStage),
        ),
      ),

      const SizedBox(height: NjSpace.sm),
      NjSegmented<VehicleType>(
        semanticLabel: strings.dVehicleLabel,
        value: _vehicle,
        onChanged: _sending
            ? (_) {}
            // Changing the vehicle re-reads the band: a boda and a bajaj are
            // not the same trip, and the design says so.
            : (type) => setState(() => _vehicle = type),
        segments: [
          NjSegment(value: VehicleType.bajaj, label: strings.pSeatsBajaj),
          NjSegment(value: VehicleType.boda, label: strings.pSeatsBoda),
        ],
      ),

      const SizedBox(height: NjSpace.lg),
      NjTextField(
        label: strings.pPriceLabel,
        prefix: 'TSh',
        hintText: bandValue == null ? null : '${bandValue.low}',
        controller: _priceController,
        enabled: !_sending,
        keyboardType: TextInputType.number,
        // Enough for any real fare and short of a fat-fingered million.
        maxLength: 7,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _failure = null),
      ),

      const SizedBox(height: NjSpace.sm),
      if (destination != null)
        NjHint(
          text: switch ((bandValue, below)) {
            (null, _) => strings.pNoBand,
            // Below the band warns and does not block. The passenger sets
            // the price; a rejected offer tells us more about the floor than
            // an accepted one does.
            (_, true) => strings.pBelowBand,
            (final found?, false) => strings.pBandHint(
                groupDigits(found.low),
                groupDigits(found.high),
              ),
          },
          tone: below ? NjHintTone.warning : NjHintTone.info,
        ),

      if (bandValue != null) ...[
        const SizedBox(height: NjSpace.md),
        NjPriceChips(
          prices: bandValue.chips,
          selected: price,
          onSelected: (picked) => setState(() {
            _priceController.text = '$picked';
            _failure = null;
          }),
        ),
      ],

      if (_failure != null) ...[
        const SizedBox(height: NjSpace.md),
        _problem(_messageFor(_failure!, strings), _failureDetail),
      ],

      const SizedBox(height: NjSpace.lg),
      NjButton(
        label: _sending ? strings.pSending : strings.pSendRequest,
        variant: NjButtonVariant.bajaj,
        loading: _sending,
        onPressed: destination == null || price == null || _sending
            ? null
            : () => _send(options),
      ),
      const SizedBox(height: NjSpace.md),
      Text(
        strings.pExpiryNote,
        textAlign: TextAlign.center,
        style: context.njText.bodySmall?.copyWith(color: nj.muted),
      ),

      // Language, sign out and the gallery, which lived on the landing
      // placeholder this screen replaced. Debug builds only; renders nothing
      // in release.
      const NjDevTools(),
    ];
  }

  Widget _problem(String message, String? detail) {
    final nj = context.nj;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: context.njText.bodySmall?.copyWith(color: nj.danger),
        ),
        if (kDebugMode && detail != null)
          Text(
            redactSecrets(detail),
            style: context.njText.bodySmall
                ?.copyWith(color: nj.muted, fontSize: 11.5),
          ),
      ],
    );
  }

  static String _messageFor(RequestFailure failure, NjStrings strings) =>
      switch (failure) {
        RequestFailure.notATrip => strings.errRequestNotATrip,
        RequestFailure.alreadyWaiting => strings.errAlreadyWaiting,
        RequestFailure.offline => strings.errOffline,
        RequestFailure.notSignedIn => strings.errUnknown,
        // The design is explicit: a silent failure means standing at the
        // road for nothing.
        RequestFailure.unknown => strings.errRequestFailed,
      };
}

/// The destination slot in the where-row: a value, or an invitation.
class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NjRadius.input),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.md,
            vertical: NjSpace.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NjRadius.input),
            border: Border.all(color: nj.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.njText.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: chosen ? nj.ink : nj.muted,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: nj.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
