import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_failure.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_otp_field.dart';
import '../widgets/nj_screen_body.dart';

/// `pOtp` — the SMS code. Component C4.
///
/// [kOtpLength] boxes, auto-advancing, accepting a pasted or autofilled code
/// whole. A wrong code clears every box and returns focus to the first, which
/// the design calls for because retyping over four stale digits on a small
/// keyboard is where people give up.
///
/// The code is checked by Supabase Auth, and the attempt cap lives there too:
/// a client-side limit would be bypassed by reinstalling the app.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  Timer? _ticker;
  String _code = '';

  @override
  void initState() {
    super.initState();
    // One timer for the resend countdown. Rebuilding once a second is enough
    // to tick a mm:ss display and cheap enough not to matter.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final auth = ref.watch(authProvider);
    final controller = ref.read(authProvider.notifier);

    // Read through the clock provider, not DateTime.now(): the controller
    // stamps codeSentAt from the same seam, and mixing the two makes the
    // countdown disagree with the guard that gates the resend.
    final secondsLeft = auth.resendIn(ref.watch(clockProvider)());
    final canResend = secondsLeft == 0 && !auth.busy;
    final complete = _code.length == kOtpLength;
    final codeRejected = auth.failure == AuthFailure.wrongCode ||
        auth.failure == AuthFailure.expiredCode;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.xl,
            vertical: NjSpace.xxl - 2,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: NjButton(
                label: strings.back,
                variant: NjButtonVariant.ghost,
                size: NjButtonSize.chip,
                expand: false,
                onPressed: auth.busy ? null : controller.editPhone,
              ),
            ),

            const SizedBox(height: NjSpace.xxl),
            Text(
              strings.otpTitle(kOtpLength),
              style: context.njText.headlineLarge,
            ),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.otpSentTo(auth.phone?.formatted ?? ''),
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.xl + 2),
            NjOtpField(
              length: kOtpLength,
              hasError: codeRejected,
              onChanged: (code) {
                // Only a keystroke clears the error, never the programmatic
                // reset that a wrong code triggers. Clearing on the reset
                // wiped the message in the same frame it appeared, so the
                // user was told nothing about why the code failed.
                if (code.isNotEmpty && auth.failure != null) {
                  controller.clearFailure();
                }
                setState(() => _code = code);
              },
              // Submitting as soon as the last digit lands saves a tap, and
              // the code is either right or it is not -- there is nothing to
              // review before pressing Verify.
              onCompleted: controller.verifyCode,
            ),

            if (codeRejected) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                auth.failure == AuthFailure.expiredCode
                    ? strings.errExpiredCode
                    : strings.errWrongCode,
                style: context.njText.bodySmall?.copyWith(
                  fontSize: 13.2,
                  color: nj.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (auth.failure != null) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                switch (auth.failure!) {
                  AuthFailure.rateLimited => strings.errRateLimited,
                  AuthFailure.providerDisabled => strings.errProviderDisabled,
                  AuthFailure.offline => strings.errOffline,
                  AuthFailure.notConfigured => strings.errNotConfigured,
                  _ => strings.errUnknown,
                },
                style: context.njText.bodySmall?.copyWith(
                  fontSize: 13.2,
                  color: nj.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // The provider's own words, in debug builds only. See the note
            // on the phone screen.
            if (kDebugMode && auth.failureDetail != null) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                'Server said: ${auth.failureDetail}',
                style: context.njText.bodySmall?.copyWith(
                  fontSize: 12,
                  color: nj.muted,
                  fontFamily: 'monospace',
                ),
              ),
            ],

            const SizedBox(height: NjSpace.lg + 2),
            if (canResend)
              Align(
                alignment: Alignment.centerLeft,
                child: NjButton(
                  label: strings.otpResend,
                  variant: NjButtonVariant.ghost,
                  size: NjButtonSize.chip,
                  expand: false,
                  onPressed: controller.resendCode,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${strings.otpDidntGet} ',
                      style: context.njText.bodySmall?.copyWith(color: nj.muted),
                    ),
                    TextSpan(
                      text: strings.otpResendIn(_mmss(secondsLeft)),
                      style: context.njText.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

            const Spacer(),
            NjButton(
              label: strings.otpVerify,
              loading: auth.busy,
              onPressed:
                  complete && !auth.busy ? () => controller.verifyCode(_code) : null,
            ),
            const SizedBox(height: NjSpace.sm + 2),
            NjButton(
              label: strings.otpWrongNumber,
              variant: NjButtonVariant.ghost,
              size: NjButtonSize.compact,
              onPressed: auth.busy ? null : controller.editPhone,
            ),
          ],
        ),
      ),
    );
  }

  /// `0:42`. Minutes are not padded; seconds are.
  static String _mmss(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
