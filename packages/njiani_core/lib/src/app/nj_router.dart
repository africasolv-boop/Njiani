import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../config/app_identity.dart';
import '../driver/driver_controller.dart';
import '../gallery/gallery_screen.dart';
import '../locale/language_controller.dart';
import '../screens/driver_pending_screen.dart';
import '../screens/driver_rejected_screen.dart';
import '../screens/driver_signup_screen.dart';
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
  _ProviderRefresh(Ref ref, NjianiApp app) {
    ref.listen(languageProvider, (_, _) => notifyListeners());
    ref.listen(authProvider, (_, _) => notifyListeners());
    // Only the driver app has a third gate, and listening to driverProvider
    // in the rider app would build it -- opening a realtime subscription on a
    // table no passenger has any business watching.
    if (app.isDriver) {
      ref.listen(driverProvider, (_, _) => notifyListeners());
    }
  }
}

/// Builds the router for [app].
///
/// One redirect holds every gate, in the order a new user meets them:
/// language, then a session, then -- in the driver app only -- verification.
GoRouter buildRouter(Ref ref, NjianiApp app) {
  final refresh = _ProviderRefresh(ref, app);
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
      if (NjRoutes.onboarding.contains(here)) return NjRoutes.home;

      // 3. Verification, in the driver app only. A passenger has no such gate,
      //    and the rider binary never reads the drivers table.
      if (app.isDriver) {
        final gate = driverGateFor(ref.read(driverProvider));
        final wantedGate = switch (gate) {
          // Nothing read yet, or a failed read. Hold position: sending a
          // driver whose data dropped out at a stage back to a blank sign-up
          // form is the worst outcome available here.
          DriverGate.unknown => here,
          DriverGate.signUp => NjRoutes.driverSignup,
          DriverGate.pending || DriverGate.suspended => NjRoutes.driverPending,
          DriverGate.rejected => NjRoutes.driverRejected,
          // Approved. Off all three gate screens, which is also what makes
          // the design's "no back navigation" true without suppressing a
          // single pop: the screens stop existing.
          DriverGate.cleared =>
            NjRoutes.driverGate.contains(here) ? NjRoutes.home : here,
        };
        if (wantedGate != here) return wantedGate;
      }

      return null;
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
          component: app.isRider
              ? 'C8 — Request a ride'
              : 'C7 — Pick a direction',
          onChangeLanguage: () {
            ref.read(languageProvider.notifier).reopen();
            context.go(NjRoutes.language);
          },
          onSignOut: () => ref.read(authProvider.notifier).signOut(),
          onOpenGallery: () => context.push(NjRoutes.gallery),
        ),
      ),
      GoRoute(
        path: NjRoutes.driverSignup,
        builder: (context, state) => const DriverSignupScreen(),
      ),
      GoRoute(
        path: NjRoutes.driverPending,
        builder: (context, state) => DriverPendingScreen(
          // Same screen, different words. The two states differ in what has
          // happened, not in what the driver can do about it from here.
          suspended: driverGateFor(ref.read(driverProvider)) ==
              DriverGate.suspended,
        ),
      ),
      GoRoute(
        path: NjRoutes.driverRejected,
        builder: (context, state) => const DriverRejectedScreen(),
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
