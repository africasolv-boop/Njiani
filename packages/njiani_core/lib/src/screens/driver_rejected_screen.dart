import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver_controller.dart';
import '../driver/driver_repository.dart';
import '../l10n/generated/nj_strings.dart';
import '../util/redact.dart';
import '../util/support_call.dart';
import '../widgets/nj_banner.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_status_row.dart';

/// `dRejected` — rejected, naming the single thing to fix. Component C6.
///
/// "Almost every rejection at this size is a bad photo, not a bad driver." So
/// the screen leads with the reason a person wrote, states that everything
/// else passed, and offers one action: replace the photo.
///
/// The checklist is not decoration. A driver reading "Rejected" needs to see
/// that their phone number and vehicle are still accepted, or they will assume
/// they are starting over — and `resubmit_driver_licence()` is what makes that
/// visible promise true, moving only the photo and the status and leaving the
/// plate, colour and vehicle type exactly as they were.
class DriverRejectedScreen extends ConsumerStatefulWidget {
  const DriverRejectedScreen({super.key});

  @override
  ConsumerState<DriverRejectedScreen> createState() =>
      _DriverRejectedScreenState();
}

class _DriverRejectedScreenState extends ConsumerState<DriverRejectedScreen> {
  bool _busy = false;
  DriverError? _error;

  /// Takes a new photo, uploads it, and re-queues the application.
  ///
  /// Two steps, in this order, because the second must not happen without the
  /// first: `resubmit_driver_licence()` moves the row back to `pending`, and
  /// doing that with a stale path would put the driver back in the queue with
  /// the same unreadable photo and no idea why they were rejected twice.
  Future<void> _retake() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final controller = ref.read(driverProvider.notifier);
      final path = await controller.captureLicence();
      if (path == null) {
        // Backed out of the camera. Nothing has changed.
        if (mounted) setState(() => _busy = false);
        return;
      }
      await controller.resubmitLicence(path);
      // The router's gate reads `pending` and replaces this screen.
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

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final driver = ref.watch(driverProvider).valueOrNull;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: [
            // The reason, first. It is written by a person and required by a
            // check constraint, so there is always something here -- an empty
            // rejection leaves a driver with nothing to act on, which the
            // design forbids and the database refuses.
            NjBanner(
              title: strings.dRejectedReasonTitle,
              message: driver?.rejectionReason,
            ),

            const SizedBox(height: NjSpace.xxl - 2),
            Text(strings.dRejectedTitle, style: context.njText.headlineLarge),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.dRejectedBody,
              style: context.njText.bodyMedium?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.lg + 2),
            NjCard(
              style: NjCardStyle.outlined,
              child: Column(
                children: [
                  NjStatusRow(
                    label: strings.phoneLabel,
                    status: strings.dStatusVerified,
                    tone: NjStatusTone.good,
                  ),
                  const _Rule(),
                  NjStatusRow(
                    label: strings.dCheckVehicle,
                    status: strings.dStatusAccepted,
                    tone: NjStatusTone.good,
                  ),
                  const _Rule(),
                  NjStatusRow(
                    label: strings.dCheckLicence,
                    status: strings.dStatusRejected,
                    tone: NjStatusTone.bad,
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                _messageFor(_error!.failure, strings),
                style: context.njText.bodySmall?.copyWith(color: nj.danger),
              ),
              if (kDebugMode && _error!.detail != null)
                Text(
                  redactSecrets(_error!.detail!),
                  style: context.njText.bodySmall?.copyWith(
                    color: nj.muted,
                    fontSize: 11.5,
                  ),
                ),
            ],

            const SizedBox(height: NjSpace.lg + 2),
            NjButton(
              label: strings.dRetakePhoto,
              icon: Icons.photo_camera_outlined,
              loading: _busy,
              onPressed: _busy ? null : _retake,
            ),
            // Hidden rather than dead when SUPPORT_PHONE is unset. Some
            // rejections -- an expired licence, a plate that does not match --
            // are not fixed by a better photo, and this is the way out of
            // those.
            if (AppConfig.hasSupportPhone) ...[
              const SizedBox(height: NjSpace.sm + 2),
              NjButton(
                label: strings.dCallNjiani,
                icon: Icons.call_outlined,
                variant: NjButtonVariant.ghost,
                onPressed: _busy ? null : () => callNjianiSupport(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _messageFor(DriverFailure failure, NjStrings strings) =>
      switch (failure) {
        DriverFailure.uploadFailed => strings.dLicenceFailed,
        DriverFailure.photoRejected => strings.errPhotoRejected,
        DriverFailure.notConfigured => strings.errNotConfigured,
        DriverFailure.offline => strings.errOffline,
        DriverFailure.staleState => strings.errDriverStale,
        DriverFailure.notSignedIn => strings.errUnknown,
        DriverFailure.unknown => strings.errUnknown,
      };
}

/// The hairline between checklist rows.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.nj.line);
}
