import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/language_controller.dart';
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
    this.onOpenGallery,
  });

  /// The component that will replace this, e.g. `C4 — Phone number`.
  final String component;

  /// Reopens the language screen. Stands in for Settings until C5.
  final VoidCallback onChangeLanguage;

  /// Opens the development-only component gallery.
  final VoidCallback? onOpenGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final language = ref.watch(languageProvider);

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
            NjCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      language.locale.endonym,
                      style: context.njText.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    language.locale.code.toUpperCase(),
                    style: context.njText.bodySmall?.copyWith(color: nj.muted),
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
