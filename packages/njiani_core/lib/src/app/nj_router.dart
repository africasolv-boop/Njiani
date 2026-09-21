import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_identity.dart';
import '../gallery/gallery_screen.dart';
import '../locale/language_controller.dart';
import '../screens/language_screen.dart';
import '../screens/placeholder_screen.dart';
import 'nj_routes.dart';

/// Bridges a Riverpod provider to [GoRouter.refreshListenable].
///
/// GoRouter re-evaluates its redirect when this notifies. Without it, the
/// guard below would only run on an explicit navigation, so confirming a
/// language would leave the user sitting on the language screen.
class _ProviderRefresh extends ChangeNotifier {
  _ProviderRefresh(Ref ref) {
    ref.listen(languageProvider, (_, _) => notifyListeners());
  }
}

/// Builds the router for [app].
///
/// The only guard at C2 is the language one. Sign-in and driver-approval
/// guards join it at C4 and C6, in this same redirect.
GoRouter buildRouter(Ref ref, NjianiApp app) {
  final refresh = _ProviderRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: NjRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final confirmed = ref.read(languageProvider).confirmed;
      final atLanguage = state.matchedLocation == NjRoutes.language;

      // The gallery is a development surface and is reachable regardless, so
      // the design system can be checked without first walking onboarding.
      if (state.matchedLocation == NjRoutes.gallery) return null;

      if (!confirmed) return atLanguage ? null : NjRoutes.language;
      // A returning user is never shown the language screen again.
      if (atLanguage) return NjRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: NjRoutes.language,
        builder: (context, state) => LanguageScreen(
          onContinue: () => context.go(NjRoutes.home),
        ),
      ),
      GoRoute(
        path: NjRoutes.home,
        builder: (context, state) => PlaceholderScreen(
          component: app.isRider ? 'C4 — Phone number' : 'C6 — Driver sign up',
          onChangeLanguage: () {
            ref.read(languageProvider.notifier).reopen();
            context.go(NjRoutes.language);
          },
          onOpenGallery: () => context.push(NjRoutes.gallery),
        ),
      ),
      GoRoute(
        path: NjRoutes.gallery,
        builder: (context, state) => NjGalleryScreen(app: app),
      ),
    ],
  );
}

/// Supplies the app identity to the router.
///
/// Overridden by each app at startup; there is no sensible default, because
/// guessing would let the driver app route like the rider app.
final njianiAppProvider = Provider<NjianiApp>(
  (ref) => throw UnimplementedError(
    'Override njianiAppProvider at startup. See NjianiRoot.bootstrap().',
  ),
);

/// The app's router.
final routerProvider = Provider<GoRouter>(
  (ref) => buildRouter(ref, ref.watch(njianiAppProvider)),
);
