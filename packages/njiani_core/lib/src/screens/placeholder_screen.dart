import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/language_controller.dart';
import '../profile/profile_controller.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_card.dart';
import '../widgets/nj_screen_body.dart';

/// Stands in for a screen that a later component will build.
///
/// Deliberately honest rather than a blank page: it names the component that
/// will replace it, so a walk-through of the app shows exactly how far the
/// build has got.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.component,
    required this.onChangeLanguage,
    this.onSignOut,
    this.onOpenGallery,
  });

  /// The component that will replace this, e.g. `C4 — Phone number`.
  final String component;

  /// Reopens the language screen. Stands in for Settings until C5.
  final VoidCallback onChangeLanguage;

  /// Ends the session, so the sign-in flow can be walked again without
  /// reinstalling the app.
  final VoidCallback? onSignOut;

  /// Opens the development-only component gallery.
  final VoidCallback? onOpenGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final language = ref.watch(languageProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: [
            const Spacer(),
            Text(
              strings.nextComponentTitle(component),
              style: context.njText.headlineLarge,
            ),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.nextComponentBody,
              style: context.njText.bodyMedium?.copyWith(color: nj.muted),
            ),
            const SizedBox(height: NjSpace.xl),
            // The account, so C5 is visible rather than merely claimed: the
            // phone that was verified, and whether the language reached the
            // server copy that SMS and push are written from.
            NjCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(
                    label: strings.phoneLabel,
                    value: profile.when(
                      data: (p) => p?.phone?.formatted ?? '—',
                      loading: () => '…',
                      error: (_, _) => '—',
                    ),
                  ),
                  const SizedBox(height: NjSpace.sm),
                  _Row(
                    label: 'Device',
                    value: language.locale.endonym,
                  ),
                  const SizedBox(height: NjSpace.sm),
                  _Row(
                    label: 'Account',
                    value: profile.when(
                      data: (p) => p == null
                          ? 'no profile row'
                          : '${p.lang.endonym}'
                              '${p.lang == language.locale ? ' ✓' : ' (out of step)'}',
                      loading: () => '…',
                      error: (error, _) => 'could not load',
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            NjButton(
              label: strings.changeLanguage,
              variant: NjButtonVariant.ghost,
              onPressed: onChangeLanguage,
            ),
            if (onSignOut != null) ...[
              const SizedBox(height: NjSpace.sm + 2),
              NjButton(
                label: strings.signOut,
                variant: NjButtonVariant.dangerGhost,
                size: NjButtonSize.compact,
                onPressed: onSignOut,
              ),
            ],
            if (onOpenGallery != null) ...[
              const SizedBox(height: NjSpace.sm + 2),
              NjButton(
                label: strings.openComponentGallery,
                variant: NjButtonVariant.ghost,
                size: NjButtonSize.compact,
                onPressed: onOpenGallery,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.njText.bodySmall?.copyWith(color: context.nj.muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.njText.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
