import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_failure.dart';
import '../auth/tz_phone.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_text_field.dart';

/// `pPhone` — the phone number. Component C4.
///
/// Supabase Auth generates and verifies the code; a Send-SMS hook delivers it
/// through Beem. Nothing in this app ever decides whether a code was correct.
///
/// Two rules from the design that are not cosmetic:
///
///   * **The `+255` is part of the field, not the value.** It cannot be
///     deleted by accident, and the user types the nine digits they know.
///   * **The field is never cleared on failure.** Retyping a phone number on
///     a moving bajaj is the worst thing this screen could ask for, so an
///     error changes the message and nothing else.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Coming back from the code screen keeps the number, so it is not retyped.
    final existing = ref.read(authProvider).phone;
    if (existing != null) _controller.text = existing.formatted;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final auth = ref.watch(authProvider);
    final controller = ref.read(authProvider.notifier);

    final digits = TzPhone.digitCount(_controller.text);
    final complete = digits == TzPhone.nationalLength;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.xl,
            vertical: NjSpace.xxl - 2,
          ),
          children: [
            const SizedBox(height: NjSpace.xxl + 2),
            Text(strings.appName, style: context.njText.displayLarge),
            Text(
              strings.tagline,
              style: context.njText.bodyMedium?.copyWith(color: nj.muted),
            ),
            const SizedBox(height: NjSpace.xxl - 2),

            Text(strings.phoneTitle, style: context.njText.headlineLarge),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.phoneSubtitle,
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.xl),
            NjTextField(
              label: strings.phoneLabel,
              prefix: '+${TzPhone.countryCode}',
              hintText: strings.phoneHint,
              controller: _controller,
              enabled: !auth.busy,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              // Generous on purpose. "+255 712 345 678" is sixteen
              // characters, and a tighter cap silently truncated a pasted
              // number and left the button disabled with nothing to explain
              // it. TzPhone decides what is valid; this only stops runaway
              // input.
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
              ],
              errorText: _errorFor(auth.failure, strings),
              onChanged: (_) {
                controller.clearFailure();
                setState(() {});
              },
              onSubmitted: (value) =>
                  complete ? controller.sendCode(value) : null,
            ),

            // The provider's own words, in debug builds only. A classifier
            // that hides the real message is a classifier nobody can fix:
            // this screen once reported a disabled provider as "enter 9
            // digits", which sent the user to correct a number that was
            // already right.
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

            const Spacer(),
            NjButton(
              label: auth.busy ? strings.sendingCode : strings.sendCode,
              loading: auth.busy,
              onPressed: complete
                  ? () => controller.sendCode(_controller.text)
                  : null,
            ),
            const SizedBox(height: NjSpace.md),
            Text(
              strings.phoneTerms,
              textAlign: TextAlign.center,
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),
          ],
        ),
      ),
    );
  }

  /// The message for [failure], or null when there is nothing wrong.
  String? _errorFor(AuthFailure? failure, NjStrings strings) =>
      switch (failure) {
        null => null,
        AuthFailure.invalidPhone => strings.phoneError,
        AuthFailure.rateLimited => strings.errRateLimited,
        AuthFailure.providerDisabled => strings.errProviderDisabled,
        AuthFailure.offline => strings.errOffline,
        AuthFailure.notConfigured => strings.errNotConfigured,
        // A code problem belongs to the code screen, not this one.
        AuthFailure.wrongCode ||
        AuthFailure.expiredCode =>
          null,
        AuthFailure.unknown => strings.errUnknown,
      };
}
