import 'package:flutter/material.dart';

import '../boot/boot_screen.dart';
import '../config/app_identity.dart';
import '../design/nj_colors.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../util/money.dart';
import '../widgets/nj_action_tile.dart';
import '../widgets/nj_avatar.dart';
import '../widgets/nj_badge.dart';
import '../widgets/nj_banner.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_choice_chips.dart';
import '../widgets/nj_empty_state.dart';
import '../widgets/nj_hint.dart';
import '../widgets/nj_live_dot.dart';
import '../widgets/nj_meter.dart';
import '../widgets/nj_otp_field.dart';
import '../widgets/nj_plate.dart';
import '../widgets/nj_route_board.dart';
import '../widgets/nj_seat_indicator.dart';
import '../widgets/nj_segmented.dart';
import '../widgets/nj_sheet.dart';
import '../widgets/nj_skeleton.dart';
import '../widgets/nj_stars.dart';
import '../widgets/nj_stat_card.dart';
import '../widgets/nj_status_row.dart';
import '../widgets/nj_text_field.dart';
import '../widgets/nj_toast.dart';
import '../widgets/nj_upload_box.dart';
import '../widgets/nj_where_row.dart';

/// The component state matrix, rendered in both themes at once.
///
/// This is what the design project's `gallery` spec asks for: not one instance
/// of each component, but every state each one can be in, side by side in
/// light and dark, so a missing state is caught here instead of inside a flow.
///
/// Side by side above 620pt, stacked below it -- on a 390pt phone two columns
/// would be 190pt each, which is narrower than the components themselves.
class NjGalleryScreen extends StatefulWidget {
  const NjGalleryScreen({
    super.key,
    required this.app,
    this.onToggleTheme,
    this.isDark = false,
  });

  /// Which app is hosting the gallery.
  final NjianiApp app;

  /// Optional single-theme override, for checking one appearance full width.
  final VoidCallback? onToggleTheme;

  /// Whether the host is currently forcing the dark theme.
  final bool isDark;

  @override
  State<NjGalleryScreen> createState() => _NjGalleryScreenState();
}

class _NjGalleryScreenState extends State<NjGalleryScreen> {
  String _vehicle = 'bajaj';
  String _tab = 'requests';
  String _triple = 'week';
  int? _price = 1500;
  int _seatsTaken = 1;
  int _rating = 4;
  bool _otpError = false;
  final _priceController = TextEditingController(text: '1,800');

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.app.label} — components'),
        actions: [
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
          const _Intro(),

          _Matrix(
            title: 'NjButton',
            spec: '4 variants × default / disabled 0.45 / loading / blocked. '
                'Primary 56pt, compact 48pt.',
            content: (context) => Column(
              children: [
                for (final (label, variant) in const [
                  ('Send request · bajaj, the committing tap',
                      NjButtonVariant.bajaj),
                  ('Send code · primary', NjButtonVariant.primary),
                  ('Share trip · ghost', NjButtonVariant.ghost),
                  ('Cancel request · dangerGhost', NjButtonVariant.dangerGhost),
                ]) ...[
                  NjButton(
                    label: label,
                    variant: variant,
                    onPressed: () => NjToast.show(context, label),
                  ),
                  const SizedBox(height: NjSpace.sm),
                ],
                const NjButton(label: 'Send code · disabled', onPressed: null),
                const SizedBox(height: NjSpace.sm),
                NjButton(
                  label: 'Sending…',
                  loading: true,
                  onPressed: () {},
                ),
                const SizedBox(height: NjSpace.sm),
                NjButton(
                  label: 'Pickup · compact 48pt',
                  size: NjButtonSize.compact,
                  onPressed: () => NjToast.show(context, 'Claimed'),
                ),
                const SizedBox(height: NjSpace.sm),
                const NjButton(
                  label: 'Seats full · blocked',
                  size: NjButtonSize.compact,
                  variant: NjButtonVariant.blocked,
                  onPressed: null,
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjTextField',
            spec: 'empty / focused teal / error danger + message / disabled.',
            content: (context) => Column(
              children: [
                const NjTextField(
                  label: 'Your price, per seat',
                  prefix: 'TSh',
                  hintText: '1,500',
                ),
                const SizedBox(height: NjSpace.md),
                NjTextField(
                  label: 'Tap to focus — border turns teal',
                  prefix: 'TSh',
                  controller: _priceController,
                ),
                const SizedBox(height: NjSpace.md),
                const NjTextField(
                  label: 'Phone number',
                  prefix: '+255',
                  errorText: 'Enter 9 digits, without the leading zero.',
                ),
                const SizedBox(height: NjSpace.md),
                const NjTextField(
                  label: 'Disabled',
                  hintText: 'Not editable',
                  enabled: false,
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjOtpField',
            spec: 'empty / partial / complete / wrong-code reset. '
                'A wrong code clears the boxes and refocuses the first.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NjOtpField(
                  autofocus: false,
                  hasError: _otpError,
                  onCompleted: (code) => NjToast.show(context, 'Code $code'),
                ),
                const SizedBox(height: NjSpace.md),
                NjButton(
                  label: _otpError ? 'Clear the error' : 'Simulate wrong code',
                  variant: NjButtonVariant.ghost,
                  size: NjButtonSize.compact,
                  onPressed: () => setState(() => _otpError = !_otpError),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjSegmented',
            spec: 'Each option selected, 2-up and 3-up.',
            content: (context) => Column(
              children: [
                NjSegmented<String>(
                  semanticLabel: 'Vehicle type',
                  value: _vehicle,
                  onChanged: (v) => setState(() => _vehicle = v),
                  segments: const [
                    NjSegment(value: 'bajaj', label: 'Bajaj · 3 seats'),
                    NjSegment(value: 'boda', label: 'Boda · 1 seat'),
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
                const SizedBox(height: NjSpace.md),
                NjSegmented<String>(
                  value: _triple,
                  onChanged: (v) => setState(() => _triple = v),
                  segments: const [
                    NjSegment(value: 'day', label: 'Day'),
                    NjSegment(value: 'week', label: 'Week'),
                    NjSegment(value: 'month', label: 'Month'),
                  ],
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjRouteBoard',
            spec: 'Yellow in both themes — it imitates a painted daladala '
                'board, not a surface.',
            fullBleed: true,
            content: (context) => Column(
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
                  to: 'Kimara Korogwe',
                  subtitle: 'On the way with Juma · T 482 DKT',
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjSeatIndicator · NjPlateBadge · NjLiveDot',
            spec: '0–3 of 3 and 0–1 of 1. Tap the seats to fill them.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _seatsTaken = (_seatsTaken + 1) % 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_seatsTaken of 3 seats taken',
                          style: context.njText.titleSmall,
                        ),
                      ),
                      NjSeatIndicator(total: 3, taken: _seatsTaken),
                    ],
                  ),
                ),
                const SizedBox(height: NjSpace.md),
                const Row(
                  children: [
                    Expanded(child: Text('Boda · one seat')),
                    NjSeatIndicator(total: 1, taken: 1),
                  ],
                ),
                const SizedBox(height: NjSpace.md),
                const Wrap(
                  spacing: NjSpace.md,
                  runSpacing: NjSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NjPlateBadge(plate: 'T 482 DKT'),
                    NjPlateBadge(plate: 'MC 214 CXK', compact: true),
                    NjLiveDot(label: 'Live'),
                  ],
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjBadge · NjStatusRow',
            spec: 'Scope markers and the rejection checklist.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: NjSpace.sm,
                  runSpacing: NjSpace.sm,
                  children: [
                    NjBadge(label: 'V2'),
                    NjBadge(label: 'V2 · NOT IN MVP', tone: NjBadgeTone.bajaj),
                    NjBadge(label: 'TSh 0', tone: NjBadgeTone.teal),
                    NjBadge(label: 'REJECTED', tone: NjBadgeTone.danger),
                  ],
                ),
                const SizedBox(height: NjSpace.md),
                NjCard(
                  style: NjCardStyle.outlined,
                  child: Column(
                    children: [
                      const NjStatusRow(
                        label: 'Phone number',
                        status: 'Verified',
                        tone: NjStatusTone.good,
                      ),
                      Divider(color: context.nj.line, height: 1),
                      const NjStatusRow(
                        label: 'Vehicle and plate',
                        status: 'Accepted',
                        tone: NjStatusTone.good,
                      ),
                      Divider(color: context.nj.line, height: 1),
                      const NjStatusRow(
                        label: 'Licence photo',
                        status: 'Rejected',
                        tone: NjStatusTone.bad,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjBanner',
            spec: 'Connection lost, and a rejected document.',
            content: (context) => const Column(
              children: [
                NjBanner(
                  title: 'No connection. Showing your last known state.',
                  showDot: true,
                ),
                SizedBox(height: NjSpace.md),
                NjBanner(
                  title: "We couldn't read your licence photo",
                  message: 'Glare across the number. Take it again in shade, '
                      'with the whole card in frame.',
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjActionTile',
            spec: 'Safety actions. The subtitle is what makes the tap safe to '
                'make.',
            content: (context) => Column(
              children: [
                NjActionTile(
                  glyph: '↗',
                  tone: NjActionTone.primary,
                  title: 'Share this trip',
                  subtitle: 'Sends a live link by WhatsApp or SMS',
                  onTap: () => NjToast.show(context, 'Trip link copied.'),
                ),
                const SizedBox(height: NjSpace.sm + 2),
                NjActionTile(
                  glyph: '☎',
                  title: 'Call Njiani',
                  subtitle: 'A person on the pilot team, 6am to 10pm',
                  onTap: () => NjToast.show(context, 'Calling…'),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjStatCard · NjMeter · NjSegmentBar',
            spec: 'Earnings hero, countdown, and seats-filled blocks.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NjStatCard(
                  caption: 'Today · 4 trips',
                  value: tsh(6200),
                  stats: const [
                    NjStat(label: 'This week', value: 'TSh 84,500'),
                    NjStat(label: 'Seats filled', value: '47 of 63'),
                  ],
                ),
                const SizedBox(height: NjSpace.md),
                const NjMeter(value: 0.62),
                const SizedBox(height: NjSpace.sm),
                Text(
                  '37 seconds left',
                  style: context.njText.bodySmall
                      ?.copyWith(fontSize: 12.5, color: context.nj.muted),
                ),
                const SizedBox(height: NjSpace.md),
                const NjSegmentBar(total: 4, filled: 3),
              ],
            ),
          ),

          _Matrix(
            title: 'Price · NjChoiceChips + NjHint',
            spec: 'Below the band still sends — it just says so first.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NjHint(
                  text: 'Most drivers on this route take TSh 1,000 to TSh 1,500',
                ),
                const SizedBox(height: NjSpace.sm),
                const NjHint(
                  text: 'Below what most drivers take. It may take longer to '
                      'find a bajaj.',
                  tone: NjHintTone.warning,
                ),
                const SizedBox(height: NjSpace.md),
                NjPriceChips(
                  prices: const [1000, 1250, 1500],
                  selected: _price,
                  onSelected: (p) => setState(() => _price = p),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjCard · NjAvatar · NjWhereRow',
            spec: 'Filled and outlined, plus the claim-lost band.',
            content: (context) => Column(
              children: [
                const NjCard(
                  child: NjWhereRow(
                    fromLabel: 'Pickup, from your location',
                    fromValue: 'Ubungo Bus Terminal',
                    toLabel: 'Going to',
                    toValue: 'Kimara Korogwe',
                  ),
                ),
                const SizedBox(height: NjSpace.md),
                NjCard(
                  child: Row(
                    children: [
                      const NjAvatar(name: 'Juma Mwinyi'),
                      const SizedBox(width: NjSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Juma Mwinyi',
                              style: context.njText.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '4.8 rating · 312 trips',
                              style: context.njText.bodySmall
                                  ?.copyWith(color: context.nj.muted),
                            ),
                          ],
                        ),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Shekilango · 400 m ahead',
                              style: context.njText.bodySmall
                                  ?.copyWith(color: context.nj.muted),
                            ),
                          ),
                          Text(tsh(1500), style: context.njText.headlineSmall),
                        ],
                      ),
                      Text(
                        'To Kimara Korogwe',
                        style: context.njText.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: NjSpace.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(NjSpace.md - 2),
                        decoration: BoxDecoration(
                          color: context.nj.dangerSoft,
                          borderRadius: BorderRadius.circular(NjRadius.chip - 2),
                        ),
                        child: Text(
                          'Taken by another driver',
                          textAlign: TextAlign.center,
                          style: context.njText.bodySmall?.copyWith(
                            color: context.nj.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjUploadBox',
            spec: 'empty / uploading / done / failed.',
            content: (context) => Column(
              children: [
                NjUploadBox(
                  label: 'Tap to photograph your licence',
                  doneLabel: 'Licence photo added',
                  onTap: () {},
                ),
                const SizedBox(height: NjSpace.sm + 2),
                NjUploadBox(
                  label: 'Tap to photograph your licence',
                  doneLabel: 'Licence photo added',
                  state: NjUploadState.uploading,
                  progress: 0.6,
                  onTap: () {},
                ),
                const SizedBox(height: NjSpace.sm + 2),
                NjUploadBox(
                  label: 'Tap to photograph your licence',
                  doneLabel: 'Licence photo added',
                  state: NjUploadState.done,
                  onTap: () {},
                ),
                const SizedBox(height: NjSpace.sm + 2),
                NjUploadBox(
                  label: 'Tap to photograph your licence',
                  doneLabel: 'Licence photo added',
                  state: NjUploadState.failed,
                  onTap: () {},
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjEmptyState · NjSkeleton · NjStars',
            spec: 'With and without an action; skeletons, not spinners.',
            content: (context) => Column(
              children: [
                NjEmptyState(
                  icon: Icons.schedule,
                  message: 'Nobody heading to Kimara Korogwe yet.\n'
                      "You'll hear a sound when a request comes in.",
                  action: NjButton(
                    label: 'Change direction',
                    expand: false,
                    size: NjButtonSize.compact,
                    variant: NjButtonVariant.ghost,
                    onPressed: () => NjToast.show(context, 'Change'),
                  ),
                ),
                const NjSkeletonCard(),
                const SizedBox(height: NjSpace.md),
                Center(
                  child: NjStars(
                    rating: _rating,
                    onRated: (value) => setState(() => _rating = value),
                  ),
                ),
              ],
            ),
          ),

          _Matrix(
            title: 'NjSheet',
            spec: 'Rides 22pt over the map behind it.',
            fullBleed: true,
            content: (context) => Container(
              color: context.nj.map,
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
                      '3 bajaj heading your way can see your offer.',
                      style: context.njText.bodyMedium
                          ?.copyWith(color: context.nj.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _Matrix(
            title: 'Type scale',
            spec: 'From the design: 41.6 / 25.6 / 24 / 21.6 / 16.8 / 13.6.',
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Njiani', style: context.njText.displayLarge),
                Text(
                  'Enter your phone number',
                  style: context.njText.headlineLarge,
                ),
                Text('Arriving in 3 min', style: context.njText.headlineMedium),
                Text(tsh(1500), style: context.njText.headlineSmall),
                const Text('Body — Njiani connects passengers with drivers '
                    'already heading the same way.'),
                Text(
                  'Small — captions and hints.',
                  style: context.njText.bodySmall
                      ?.copyWith(color: context.nj.muted),
                ),
              ],
            ),
          ),

          const _Swatches(),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          NjSpace.xl,
          NjSpace.lg,
          NjSpace.xl,
          0,
        ),
        child: Text(
          'Every component in every state, light above dark, so a missing '
          'state is caught here instead of inside a flow.',
          style: context.njText.bodySmall?.copyWith(color: context.nj.muted),
        ),
      );
}

/// Renders one component's states in both themes.
///
/// Side by side on a tablet, stacked on a phone: at 390pt two columns would be
/// 190pt each, narrower than several of the components being shown.
class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.title,
    required this.content,
    this.spec,
    this.fullBleed = false,
  });

  final String title;
  final WidgetBuilder content;
  final String? spec;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 620;

    final panels = [
      _ThemePanel(label: 'Light', dark: false, fullBleed: fullBleed, content: content),
      _ThemePanel(label: 'Dark', dark: true, fullBleed: fullBleed, content: content),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NjSpace.xl,
            NjSpace.xxl,
            NjSpace.xl,
            NjSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: context.njText.labelSmall?.copyWith(
                  color: context.nj.muted,
                  letterSpacing: 1.2,
                ),
              ),
              if (spec != null) ...[
                const SizedBox(height: NjSpace.xs),
                Text(
                  spec!,
                  style: context.njText.bodySmall
                      ?.copyWith(color: context.nj.muted),
                ),
              ],
            ],
          ),
        ),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final panel in panels) Expanded(child: panel),
              ],
            ),
          )
        else
          Column(children: panels),
      ],
    );
  }
}

class _ThemePanel extends StatelessWidget {
  const _ThemePanel({
    required this.label,
    required this.dark,
    required this.content,
    required this.fullBleed,
  });

  final String label;
  final bool dark;
  final WidgetBuilder content;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final theme = dark ? NjTheme.dark : NjTheme.light;
    final nj = dark ? NjColors.dark : NjColors.light;

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Container(
          color: nj.bg,
          padding: EdgeInsets.fromLTRB(
            fullBleed ? 0 : NjSpace.xl,
            NjSpace.md,
            fullBleed ? 0 : NjSpace.xl,
            NjSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: fullBleed ? NjSpace.xl : 0,
                  bottom: NjSpace.sm,
                ),
                child: Text(
                  label,
                  style: context.njText.labelSmall?.copyWith(color: nj.muted),
                ),
              ),
              DefaultTextStyle(
                style: theme.textTheme.bodyMedium!,
                child: content(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  static const _names = [
    'bg',
    'surface',
    'surfaceAlt',
    'ink',
    'muted',
    'line',
    'bajaj',
    'teal',
    'tealSoft',
    'danger',
    'map',
    'live',
  ];

  static Color _of(NjColors nj, String name) => switch (name) {
        'bg' => nj.bg,
        'surface' => nj.surface,
        'surfaceAlt' => nj.surfaceAlt,
        'ink' => nj.ink,
        'muted' => nj.muted,
        'line' => nj.line,
        'bajaj' => nj.bajaj,
        'teal' => nj.teal,
        'tealSoft' => nj.tealSoft,
        'danger' => nj.danger,
        'map' => nj.map,
        _ => nj.live,
      };

  static String _hex(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) => _Matrix(
        title: 'Tokens',
        spec: 'Every value matches the design project exactly. '
            'bajaj and live are identical in both themes.',
        content: (context) {
          final nj = context.nj;
          return Wrap(
            spacing: NjSpace.sm,
            runSpacing: NjSpace.sm,
            children: [
              for (final name in _names)
                SizedBox(
                  width: 82,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _of(nj, name),
                          borderRadius: BorderRadius.circular(NjRadius.plate),
                          border: Border.all(color: nj.line),
                        ),
                      ),
                      const SizedBox(height: NjSpace.xs),
                      Text(
                        name,
                        style: context.njText.labelSmall
                            ?.copyWith(letterSpacing: 0),
                      ),
                      Text(
                        _hex(_of(nj, name)),
                        style: context.njText.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: nj.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
}
