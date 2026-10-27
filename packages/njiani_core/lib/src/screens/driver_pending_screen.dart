import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver.dart';
import '../driver/driver_controller.dart';
import '../l10n/generated/nj_strings.dart';
import '../profile/profile_controller.dart';
import '../util/support_call.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_plate.dart';
import '../widgets/nj_screen_body.dart';
import 'driver_signup_screen.dart';

/// `dPending` — under review. Component C6.
///
/// "A driver who submits at a stage will close the app and come back. This
/// screen has to be the whole status, with nothing to do." So it shows exactly
/// what was submitted, says an SMS is coming, and says the app can be closed.
///
/// It also carries the suspended state, which the design specifies as the same
/// layout with different copy and the support number made prominent. Keeping
/// them in one screen is deliberate: they differ in what has happened, not in
/// what the driver can do about it from here.
///
/// The approval arrives without a tap. [DriverController] subscribes to the
/// driver's own row, and the router's gate replaces this screen the moment
/// `status` reaches `approved`. **Check again** is the fallback for a socket
/// that died while the app was backgrounded — a driver should never have to
/// reinstall to discover they were approved.
class DriverPendingScreen extends ConsumerStatefulWidget {
  const DriverPendingScreen({super.key, this.suspended = false});

  /// Renders the suspended wording instead of the under-review wording.
  final bool suspended;

  @override
  ConsumerState<DriverPendingScreen> createState() =>
      _DriverPendingScreenState();
}

class _DriverPendingScreenState extends ConsumerState<DriverPendingScreen>
    with WidgetsBindingObserver {
  bool _checking = false;

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
    // Coming back to the app is the single most likely moment for this screen
    // to be stale: the realtime socket does not survive being backgrounded on
    // either platform, and the decision may well have been made in between.
    if (state == AppLifecycleState.resumed) {
      ref.read(driverProvider.notifier).refresh();
    }
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await ref.read(driverProvider.notifier).refresh();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final driver = ref.watch(driverProvider).valueOrNull;
    final name = ref.watch(profileProvider).valueOrNull?.displayName;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkAgain,
          child: NjScreenBody(
            padding: const EdgeInsets.all(NjSpace.xl),
            // This screen is short, so it fits without scrolling on most
            // phones -- and a RefreshIndicator over a scroll view that
            // cannot overscroll is a gesture that silently does nothing.
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: NjSpace.xxxl + NjSpace.xxl),
              Center(
                child: widget.suspended
                    ? _StatusGlyph(
                        icon: Icons.pause_rounded,
                        ring: nj.danger,
                      )
                    : _StatusGlyph(
                        icon: Icons.schedule_rounded,
                        ring: nj.bajaj,
                      ),
              ),
              const SizedBox(height: NjSpace.lg),
              Text(
                widget.suspended
                    ? strings.dSuspendedTitle
                    : strings.dPendingTitle,
                textAlign: TextAlign.center,
                style: context.njText.headlineLarge,
              ),
              const SizedBox(height: NjSpace.sm),
              Text(
                widget.suspended ? strings.dSuspendedBody : strings.dPendingBody,
                textAlign: TextAlign.center,
                style: context.njText.bodyMedium?.copyWith(color: nj.muted),
              ),

              // What is under review. A driver who is not sure the submission
              // went through can read it back here, which is cheaper for
              // everybody than a phone call.
              if (driver != null) ...[
                const SizedBox(height: NjSpace.xl),
                _SubmittedCard(driver: driver, name: name),
              ],

              const SizedBox(height: NjSpace.xl),

              // Suspended: calling is the only thing that moves this, so it
              // takes the primary slot and Check again goes below it. Under
              // review: there is nothing to call about yet.
              if (widget.suspended && AppConfig.hasSupportPhone) ...[
                NjButton(
                  label: strings.dCallNjiani,
                  icon: Icons.call_outlined,
                  onPressed: () => callNjianiSupport(context),
                ),
                const SizedBox(height: NjSpace.sm + 2),
              ],
              NjButton(
                label: strings.dCheckAgain,
                icon: Icons.refresh_rounded,
                variant: NjButtonVariant.ghost,
                loading: _checking,
                onPressed: _checking ? null : _checkAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular glyph at the top of the screen.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.icon, required this.ring});

  final IconData icon;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: nj.surfaceAlt, shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 5),
          ),
          child: Center(child: Icon(icon, size: 20, color: nj.ink)),
        ),
      ),
    );
  }
}

/// What was submitted: the name, the vehicle, the colour and the plate.
class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard({required this.driver, required this.name});

  final Driver driver;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return NjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.dSubmittedLabel,
            style: context.njText.bodySmall?.copyWith(color: nj.muted),
          ),
          if (name != null && name!.isNotEmpty)
            Text(
              name!,
              style: context.njText.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: NjSpace.xs),
          Row(
            children: [
              // Flexible, because the plate deliberately does not shrink: a
              // half-rendered plate cannot identify a vehicle, so its
              // siblings give way instead.
              Flexible(
                child: Text(
                  '${driver.vehicleType == VehicleType.boda ? strings.dVehicleBoda : strings.dVehicleBajaj}'
                  ' · ${njColourLabel(driver.colour, strings)}',
                  style: context.njText.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: NjSpace.sm),
              NjPlateBadge(plate: driver.plate, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
