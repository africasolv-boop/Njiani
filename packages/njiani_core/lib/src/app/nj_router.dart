import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../config/app_identity.dart';
import '../gallery/gallery_screen.dart';
import '../locale/language_controller.dart';
import '../screens/language_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/phone_screen.dart';
import '../screens/placeholder_screen.dart';
import 'nj_routes.dart';

/// Bridges Riverpod providers to [GoRouter.refreshListenable].
///
/// GoRouter re-evaluates its redirect when this notifies. Without it the guard
/// would only run on an explicit navigation, so verifying a code would leave
/// the user sitting on the code screen.
class _ProviderRefresh extends ChangeNotifier {
  _ProviderRefresh(Ref ref) {
    ref.listen(languageProvider, (_, _) => notifyListeners());
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

/// Builds the router for [app].
///
/// One redirect holds every gate, in the order a new user meets them:
/// language, then a session. The driver-approval gate joins it at C6.
GoRouter buildRouter(Ref ref, NjianiApp app) {
  final refresh = _ProviderRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: NjRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final here = state.matchedLocation;

      // The gallery is a development surface, reachable without walking
      // onboarding first so the design system can be checked at any time.
      if (here == NjRoutes.gallery) return null;

      // 1. Language, before anything else: every screen after this has to be
      //    in a language the user can read.
      if (!ref.read(languageProvider).confirmed) {
        return here == NjRoutes.language ? null : NjRoutes.language;
      }

      // 2. A session.
      final auth = ref.read(authProvider);
      final wanted = switch (auth.step) {
        AuthStep.phone => NjRoutes.phone,
        AuthStep.code => NjRoutes.code,
        AuthStep.signedIn => null,
      };

      if (wanted != null) return here == wanted ? null : wanted;

      // Signed in: onboarding routes are behind the user now.
      return NjRoutes.onboarding.contains(here) ? NjRoutes.home : null;
    },
    routes: [
      GoRoute(
        path: NjRoutes.language,
        builder: (context, state) => LanguageScreen(
          // The auth guard decides what comes next, so this only has to stop
          // asking about language.
          onContinue: () => context.go(NjRoutes.home),
        ),
      ),
      GoRoute(
        path: NjRoutes.phone,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: NjRoutes.code,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: NjRoutes.home,
        builder: (context, state) => PlaceholderScreen(
          component: app.isRider ? 'C8 — Request a ride' : 'C6 — Driver sign up',
          onChangeLanguage: () {
            ref.read(languageProvider.notifier).reopen();
            context.go(NjRoutes.language);
          },
          onSignOut: () => ref.read(authProvider.notifier).signOut(),
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
