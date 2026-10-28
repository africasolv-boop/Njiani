import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/nj_routes.dart';
import '../auth/auth_controller.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/language_controller.dart';

/// Change language, sign out, and the component gallery.
///
/// **Debug builds only**, and it renders nothing in a release build.
///
/// These three lived on the landing placeholder, which the real screens
/// replaced at C7, C8 and C9. Two of them are not development features at all
/// — changing language and signing out belong on a Settings screen, which
/// does not exist yet. Keeping them reachable here means the sign-in flow can
/// still be re-walked on a device without reinstalling, and the design system
/// can still be checked, until that screen is built.
///
/// One widget rather than a copy per landing screen: three copies of a
/// temporary thing is how a temporary thing survives.
class NjDevTools extends ConsumerWidget {
  const NjDevTools({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: NjSpace.lg),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: NjSpace.sm,
        children: [
          TextButton(
            onPressed: () => context.push(NjRoutes.gallery),
            child: Text(strings.openComponentGallery),
          ),
          TextButton(
            onPressed: () {
              ref.read(languageProvider.notifier).reopen();
              context.go(NjRoutes.language);
            },
            child: Text(strings.changeLanguage),
          ),
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            child: Text(
              strings.signOut,
              style: TextStyle(color: nj.danger),
            ),
          ),
        ],
      ),
    );
  }
}
