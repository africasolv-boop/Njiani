import 'package:flutter/material.dart';

import '../boot/boot_screen.dart';
import '../config/app_identity.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../util/money.dart';
import '../widgets/nj_avatar.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_choice_chips.dart';
import '../widgets/nj_empty_state.dart';
import '../widgets/nj_hint.dart';
import '../widgets/nj_live_dot.dart';
import '../widgets/nj_otp_field.dart';
import '../widgets/nj_plate.dart';
import '../widgets/nj_route_board.dart';
import '../widgets/nj_seat_indicator.dart';
import '../widgets/nj_segmented.dart';
import '../widgets/nj_sheet.dart';
import '../widgets/nj_stars.dart';
import '../widgets/nj_text_field.dart';
import '../widgets/nj_toast.dart';
import '../widgets/nj_upload_box.dart';
import '../widgets/nj_where_row.dart';

/// Every design-system component on one screen, in both themes.
///
/// This is the C1 deliverable: somewhere to judge the whole visual language
/// against the pitch deck at once, and to check that nothing breaks in dark
/// mode or at a small screen size. It is a development surface -- no app screen
/// routes to it, and it disappears once real screens exist.
class NjGalleryScreen extends StatefulWidget {
  const NjGalleryScreen({
    super.key,
    required this.app,
    required this.onToggleTheme,
    required this.isDark,
  });

  /// Which app is hosting the gallery.
  final NjianiApp app;

  /// Flips between the light and dark theme.
  final VoidCallback onToggleTheme;

  /// Whether the dark theme is showing.
  final bool isDark;

  @override
  State<NjGalleryScreen> createState() => _NjGalleryScreenState();
}

class _NjGalleryScreenState extends State<NjGalleryScreen> {
  String _vehicle = 'bajaj';
  String _tab = 'requests';
  int? _price = 1500;
  int _seatsTaken = 1;
  int _rating = 4;
  bool _licenceAdded = false;
  bool _loading = false;
  String _otp = '';
  final _phoneController = TextEditingController(text: '712 345 678');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.app.label} — components'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'Switch to light' : 'Switch to dark',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Build configuration',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BootScreen(app: widget.app),
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: NjSpace.xxxl * 2),
        children: [
          _Section(
            title: 'Route board',
            note: 'The signature component. Yellow in both themes — it copies '
                'the painted route boards on daladala, so it should not follow '
                'the device appearance.',
            fullBleed: true,
            child: Column(
              children: [
                NjRouteBoard(
                  from: 'Ubungo',
                  to: 'Kimara Korogwe',
                  subtitle: "You're online",
                  actionLabel: 'Change',
                  onAction: () => NjToast.show(context, 'Change direction'),
                ),
                const SizedBox(height: NjSpace.sm),
                const NjRouteBoard(
                  from: 'Ubungo',
                  to: 'Mbezi Mwisho',
                  subtitle: 'On the way with Juma, T 482 DKT',
                ),
              ],
            ),
          ),

          _Section(
            title: 'Seats',
            note: 'Three blocks for a bajaj, one for a boda. Tap to fill.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_seatsTaken of 3 seats taken',
                            style: context.njText.titleSmall,
                          ),
                          Text(
                            _seatsTaken >= 3
                                ? 'Drop someone off to take more'
                                : 'You can take ${3 - _seatsTaken} more',
                            style: context.njText.bodySmall
                                ?.copyWith(color: nj.muted),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _seatsTaken = (_seatsTaken + 1) % 4),
                      child: NjSeatIndicator(total: 3, taken: _seatsTaken),
                    ),
                  ],
                ),
                const SizedBox(height: NjSpace.lg),
                const Row(
                  children: [
                    Expanded(child: Text('Boda, one seat')),
                    NjSeatIndicator(total: 1, taken: 1),
                  ],
                ),
              ],
            ),
          ),

          _Section(
            title: 'Number plate',
            note: 'A safety component — passengers verify the bajaj by reading '
                'it. Fixed plate colours in both themes.',
            child: const Wrap(
              spacing: NjSpace.md,
              runSpacing: NjSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                NjPlateBadge(plate: 'T 482 DKT'),
                NjPlateBadge(plate: 'MC 214 CXK', compact: true),
              ],
            ),
          ),

          _Section(
            title: 'Buttons',
            note: 'Yellow is reserved for the decisive tap — Send request, '
                'Start heading — so it never looks like a routine action.',
            child: Column(
              children: [
                NjButton(
                  label: 'Send request',
                  variant: NjButtonVariant.bajaj,
                  onPressed: () => NjToast.show(context, 'Request sent'),
                ),
                const SizedBox(height: NjSpace.md),
                NjButton(
                  label: 'Verify',
                  onPressed: () => NjToast.show(context, 'Verified'),
                ),
                const SizedBox(height: NjSpace.md),
                NjButton(
                  label: 'Call Juma',
                  icon: Icons.phone_outlined,
                  variant: NjButtonVariant.ghost,
                  onPressed: () => NjToast.show(context, 'Calling…'),
                ),
                const SizedBox(height: NjSpace.md),
                NjButton(
                  label: 'Cancel request',
                  variant: NjButtonVariant.dangerGhost,
                  onPressed: () => NjToast.show(context, 'Cancelled'),
                ),
                const SizedBox(height: NjSpace.md),
                const NjButton(label: 'Send code', onPressed: null),
                const SizedBox(height: NjSpace.md),
                NjButton(
                  label: 'Finding a driver',
                  loading: _loading,
                  onPressed: () async {
                    setState(() => _loading = true);
                    await Future<void>.delayed(const Duration(seconds: 2));
                    if (mounted) setState(() => _loading = false);
                  },
                ),
              ],
            ),
          ),

          _Section(
            title: 'Where to',
            note: 'Teal dot for pickup, yellow square for destination — the '
                'same two marks the map uses.',
            child: const NjWhereRow(
              fromLabel: 'Pickup, from your location',
              fromValue: 'Ubungo Bus Terminal',
              toLabel: 'Going to',
              toValue: 'Kimara Korogwe',
            ),
          ),

          _Section(
            title: 'Vehicle and tabs',
            child: Column(
              children: [
                NjSegmented<String>(
                  semanticLabel: 'Vehicle type',
                  value: _vehicle,
                  onChanged: (v) => setState(() => _vehicle = v),
                  segments: const [
                    NjSegment(value: 'bajaj', label: 'Bajaj'),
                    NjSegment(value: 'boda', label: 'Boda boda'),
                  ],
                ),
                const SizedBox(height: NjSpace.md),
                NjSegmented<String>(
                  value: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                  segments: const [
                    NjSegment(value: 'requests', label: 'Requests'),
                    NjSegment(value: 'onboard', label: 'On board (1)'),
                  ],
                ),
              ],
            ),
          ),

          _Section(
            title: 'Your price',
            note: 'An offer below the band still sends — it just says so first. '
                'The passenger sets the price, not the app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NjTextField(
                  label: 'Your price',
                  prefix: 'TSh',
                  hintText: '1000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: NjSpace.sm),
                NjHint(
                  text: (_price ?? 0) < 1000
                      ? 'Below what most drivers take. It may take longer to '
                          'find a bajaj.'
                      : 'Most drivers on this route take ${tsh(1000)} to '
                          '${tsh(1500)}',
                  tone: (_price ?? 0) < 1000
                      ? NjHintTone.warning
                      : NjHintTone.info,
                ),
                const SizedBox(height: NjSpace.md),
                NjPriceChips(
                  prices: const [800, 1200, 1500],
                  selected: _price,
                  onSelected: (p) => setState(() => _price = p),
                ),
              ],
            ),
          ),

          _Section(
            title: 'Phone and code',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NjTextField(
                  label: 'Phone number',
                  prefix: '+255',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: NjSpace.lg),
                NjTextField(
                  label: 'Plate number',
                  hintText: 'T 482 DKT',
                  errorText: 'Enter the plate as it appears on the vehicle',
                ),
                const SizedBox(height: NjSpace.lg),
                Text('4-digit code', style: context.njText.labelMedium),
                const SizedBox(height: NjSpace.sm),
                NjOtpField(
                  autofocus: false,
                  onChanged: (code) => setState(() => _otp = code),
                  onCompleted: (code) => NjToast.show(context, 'Code $code'),
                ),
                if (_otp.isNotEmpty) ...[
                  const SizedBox(height: NjSpace.sm),
                  Text(
                    'Typed: $_otp',
                    style: context.njText.bodySmall?.copyWith(color: nj.muted),
                  ),
                ],
              ],
            ),
          ),

          _Section(
            title: 'Driver card',
            child: Column(
              children: [
                NjCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const NjAvatar(name: 'Juma Mwinyi'),
                          const SizedBox(width: NjSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Juma Mwinyi',
                                  style: context.njText.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '4.8 rating, 312 trips',
                                  style: context.njText.bodySmall
                                      ?.copyWith(color: nj.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NjSpace.md),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          NjPlateBadge(plate: 'T 482 DKT'),
                          SizedBox(width: NjSpace.sm),
                          // The plate is fixed-width by design, so whatever
                          // sits beside it is what has to yield.
                          Flexible(
                            child: Text(
                              'Blue bajaj',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NjSpace.md),
                NjCard(
                  style: NjCardStyle.outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Shekilango, 400 m ahead',
                              style: context.njText.bodySmall
                                  ?.copyWith(color: nj.muted),
                            ),
                          ),
                          Text(tsh(1500), style: context.njText.headlineSmall),
                        ],
                      ),
                      Text(
                        'To Kimara Korogwe',
                        style: context.njText.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: NjSpace.md),
                      NjButton(
                        label: 'Pickup',
                        onPressed: () => NjToast.show(
                          context,
                          'Neema is yours. Pick up at Shekilango.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NjSpace.md),
                Container(
                  padding: const EdgeInsets.all(NjSpace.md),
                  decoration: BoxDecoration(
                    color: nj.dangerSoft,
                    borderRadius: BorderRadius.circular(NjRadius.chip - 2),
                  ),
                  child: Center(
                    child: Text(
                      'Taken by another driver',
                      style: context.njText.bodySmall?.copyWith(
                        color: nj.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _Section(
            title: 'Licence upload',
            child: NjUploadBox(
              label: 'Tap to take a photo of your license',
              doneLabel: 'License photo added',
              done: _licenceAdded,
              onTap: () => setState(() => _licenceAdded = !_licenceAdded),
            ),
          ),

          _Section(
            title: 'Rating',
            child: Center(
              child: NjStars(
                rating: _rating,
                onRated: (value) => setState(() => _rating = value),
              ),
            ),
          ),

          _Section(
            title: 'Live and empty states',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NjLiveDot(
                  label: 'Live, passengers heading to Kimara Korogwe',
                ),
                NjEmptyState(
                  icon: Icons.route_outlined,
                  message: 'No requests yet on this road.\n'
                      'New ones will appear here.',
                  action: NjButton(
                    label: 'Change direction',
                    expand: false,
                    variant: NjButtonVariant.ghost,
                    onPressed: () => NjToast.show(context, 'Change direction'),
                  ),
                ),
              ],
            ),
          ),

          _Section(
            title: 'Bottom sheet',
            note: 'Rides 22pt over whatever is behind it, so it reads as '
                'sitting on top of the map.',
            fullBleed: true,
            child: Container(
              color: nj.map,
              padding: const EdgeInsets.only(top: NjSpace.xxxl),
              child: NjSheet(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finding a bajaj to Kimara',
                      style: context.njText.headlineLarge,
                    ),
                    const SizedBox(height: NjSpace.sm),
                    Text(
                      '3 bajajs on Morogoro Road are heading your way.',
                      style: context.njText.bodyMedium
                          ?.copyWith(color: nj.muted),
                    ),
                    const SizedBox(height: NjSpace.lg),
                    NjButton(
                      label: 'Cancel request',
                      variant: NjButtonVariant.dangerGhost,
                      onPressed: () => NjToast.show(context, 'Cancelled'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _Section(
            title: 'Type scale',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Njiani', style: context.njText.displayLarge),
                Text(
                  'Enter your phone number',
                  style: context.njText.headlineLarge,
                ),
                Text('Arriving in 3 min', style: context.njText.headlineMedium),
                Text(tsh(1500), style: context.njText.headlineSmall),
                const SizedBox(height: NjSpace.sm),
                Text('Body — 16px, 1.45 line height. Njiani connects '
                    'passengers with bajaj and boda boda drivers who are '
                    'already heading in the same direction.'),
                Text(
                  'Small — captions and hints.',
                  style: context.njText.bodySmall?.copyWith(color: nj.muted),
                ),
              ],
            ),
          ),

          _Section(
            title: 'Palette',
            child: const Wrap(
              spacing: NjSpace.sm,
              runSpacing: NjSpace.sm,
              children: [
                _Swatch(name: 'bajaj', token: _Token.bajaj),
                _Swatch(name: 'teal', token: _Token.teal),
                _Swatch(name: 'tealSoft', token: _Token.tealSoft),
                _Swatch(name: 'danger', token: _Token.danger),
                _Swatch(name: 'dangerSoft', token: _Token.dangerSoft),
                _Swatch(name: 'ink', token: _Token.ink),
                _Swatch(name: 'muted', token: _Token.muted),
                _Swatch(name: 'line', token: _Token.line),
                _Swatch(name: 'surface', token: _Token.surface),
                _Swatch(name: 'surfaceAlt', token: _Token.surfaceAlt),
                _Swatch(name: 'bg', token: _Token.bg),
                _Swatch(name: 'map', token: _Token.map),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.note,
    this.fullBleed = false,
  });

  final String title;
  final Widget child;
  final String? note;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NjSpace.xl,
            NjSpace.xxl,
            NjSpace.xl,
            NjSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: context.njText.labelSmall?.copyWith(
                  color: nj.muted,
                  letterSpacing: 1.2,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: NjSpace.xs),
                Text(
                  note!,
                  style: context.njText.bodySmall?.copyWith(color: nj.muted),
                ),
              ],
            ],
          ),
        ),
        if (fullBleed)
          child
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NjSpace.xl),
            child: child,
          ),
        const SizedBox(height: NjSpace.sm),
        Divider(color: nj.line, height: NjSpace.xxl),
      ],
    );
  }
}

enum _Token {
  bajaj,
  teal,
  tealSoft,
  danger,
  dangerSoft,
  ink,
  muted,
  line,
  surface,
  surfaceAlt,
  bg,
  map,
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.token});

  final String name;
  final _Token token;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final color = switch (token) {
      _Token.bajaj => nj.bajaj,
      _Token.teal => nj.teal,
      _Token.tealSoft => nj.tealSoft,
      _Token.danger => nj.danger,
      _Token.dangerSoft => nj.dangerSoft,
      _Token.ink => nj.ink,
      _Token.muted => nj.muted,
      _Token.line => nj.line,
      _Token.surface => nj.surface,
      _Token.surfaceAlt => nj.surfaceAlt,
      _Token.bg => nj.bg,
      _Token.map => nj.map,
    };

    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(NjRadius.chip - 2),
              border: Border.all(color: nj.line),
            ),
          ),
          const SizedBox(height: NjSpace.xs),
          Text(name, style: context.njText.bodySmall),
        ],
      ),
    );
  }
}
