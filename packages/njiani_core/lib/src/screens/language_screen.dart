import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/language_controller.dart';
import '../locale/nj_locale.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_option_tile.dart';
import '../widgets/nj_screen_body.dart';

/// `pLang` — the language choice. Component C2.
///
/// Shown once, before authentication, because every screen after it has to be
/// in the right language. Kiswahili is pre-selected: it is the first language
/// of the pilot corridor.
///
/// Two details from the design that look like inconsistencies but are not:
///
///   * The heading appears in **both** languages at once. On this one screen
///     the user cannot yet reliably read either, so showing only one would be
///     a guess. The same goes for the Continue button.
///   * Tapping an option changes the rest of the screen immediately, without
///     confirming. The choice is demonstrated rather than described, and
///     nothing is written until Continue.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key, required this.onContinue});

  /// Where to go once the choice is confirmed.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    final language = ref.watch(languageProvider);
    final controller = ref.read(languageProvider.notifier);

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.xl,
            vertical: NjSpace.xxl - 2,
          ),
          children: [
            // Wordmark.
            const SizedBox(height: NjSpace.xxl + 2),
            Text(strings.appName, style: context.njText.displayLarge),
            Text(
              strings.tagline,
              style: context.njText.bodyMedium?.copyWith(color: nj.muted),
            ),
            const SizedBox(height: NjSpace.xxl - 2),

            // Bilingual heading. Both lines, always.
            Text(
              '${strings.languageHeadingSw}\n${strings.languageHeadingEn}',
              style: context.njText.headlineLarge,
            ),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.languageChangeLater,
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.xl),
            NjOptionTile(
              label: strings.languageSwahili,
              note: strings.languageSwahiliHint,
              selected: language.locale == NjLocale.sw,
              onTap: () => controller.preview(NjLocale.sw),
            ),
            const SizedBox(height: NjSpace.sm + 2),
            NjOptionTile(
              label: strings.languageEnglish,
              note: strings.languageEnglishHint,
              selected: language.locale == NjLocale.en,
              onTap: () => controller.preview(NjLocale.en),
            ),

            const Spacer(),
            NjButton(
              label: strings.languageContinue,
              onPressed: () async {
                await controller.confirm();
                onContinue();
              },
            ),
          ],
        ),
      ),
    );
  }
}
