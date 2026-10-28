import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../config/app_identity.dart';
import '../driver/driver_controller.dart';
import '../driver/driver_session.dart';
import '../driver/session_controller.dart';
import '../gallery/gallery_screen.dart';
import '../locale/language_controller.dart';
import '../profile/profile_controller.dart';
import '../screens/driver_direction_screen.dart';
import '../screens/driver_feed_screen.dart';
import '../screens/driver_pending_screen.dart';
import '../screens/driver_rejected_screen.dart';
import '../screens/driver_signup_screen.dart';
import '../screens/language_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/passenger_details_screen.dart';
import '../screens/phone_screen.dart';
import '../screens/request_screen.dart';
import '../screens/settling_screen.dart';
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
      ref.listen(sessionProvider, (_, _) => notifyListeners());
    } else {
      // The rider's name gate. Without this the redirect would not re-run
      // when the profile lands, and a passenger would sit on the details
      // screen after saving.
      ref.listen(profileProvider, (_, _) => notifyListeners());
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

      // 3. The rider app: a name before a request.
      //
      //    From C10 a driver is told who they are picking up, and "a
      //    passenger" is not a thing you can call out at a stage.
      //
      //    Gated on a KNOWN empty name only. A profile that is still loading
      //    or that failed to read holds nothing up -- being unable to ask for
      //    a ride because a nicety could not be read is worse than an
      //    unnamed passenger, and it is the same mistake the driver gate
      //    made by resting at `home`.
      if (app.isRider) {
        final profile = ref.read(profileProvider);
        final needsName =
            profile is AsyncData && !(profile.value?.hasName ?? true);

        if (needsName) {
          if (here != NjRoutes.passengerDetails) {
            return NjRoutes.passengerDetails;
          }
        } else if (here == NjRoutes.home ||
            here == NjRoutes.passengerDetails) {
          return NjRoutes.request;
        }
      }

      // 4. Verification and a declared heading, in the driver app only. A
      //    passenger has no such gate, and the rider binary never reads the
      //    drivers table.
      //
      //    THE DRIVER APP HAS NO `home` SCREEN. Every branch below names a
      //    real one, because an earlier version let two cases fall through
      //    and rest at `/` -- where the landing placeholder lives. An
      //    approved driver whose session read failed sat on "This screen
      //    arrives in the next component" with no way out and nothing
      //    anywhere saying why.
      if (app.isDriver) {
        final wanted = driverDestination(
          gate: driverGateFor(ref.read(driverProvider)),
          session: ref.read(sessionProvider),
          here: here,
        );
        if (wanted != here) return wanted;
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
        // Nobody stays here. Both apps redirect away within a frame, and
        // what this renders is what a cold start shows while the profile or
        // the driver record is read. It used to be the landing placeholder,
        // which is a fine stand-in and a bad resting place.
        builder: (context, state) => const SettlingScreen(),
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
        path: NjRoutes.passengerDetails,
        builder: (context, state) => const PassengerDetailsScreen(),
      ),
      GoRoute(
        path: NjRoutes.request,
        builder: (context, state) => const RequestScreen(),
      ),
      GoRoute(
        path: NjRoutes.driverDirection,
        builder: (context, state) => const DriverDirectionScreen(),
      ),
      GoRoute(
        path: NjRoutes.driverFeed,
        builder: (context, state) => const DriverFeedScreen(),
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

/// Where a driver belongs, given what is known so far.
///
/// Pulled out of the redirect and given a name because it is the one place
/// three states meet — verification, the session, and where the driver
/// already is — and because every one of its branches has to name a real
/// screen.
///
/// `home` is not one. In the driver app it is a landing route with a
/// placeholder on it, and resting there is always a bug: the two cases that
/// used to fall through to it were a failed driver read and a failed session
/// read, and both left an approved driver stranded with nothing on screen
/// explaining it.
@visibleForTesting
String driverDestination({
  required DriverGate gate,
  required AsyncValue<DriverSession?> session,
  required String here,
}) {
  final onGateScreen = NjRoutes.driverGate.contains(here);

  switch (gate) {
    case DriverGate.signUp:
      return NjRoutes.driverSignup;
    case DriverGate.pending:
    case DriverGate.suspended:
      return NjRoutes.driverPending;
    case DriverGate.rejected:
      return NjRoutes.driverRejected;

    case DriverGate.loading:
      // Hold everything, including at `home` -- which renders a spinner and
      // exists for exactly this moment. Moving now and moving back when the
      // read lands is a flicker at best, and at worst parks an online driver
      // on the picker, which they are then allowed to stay on.
      return here;

    case DriverGate.unreadable:
      // Hold position: sending a driver whose data dropped out at a stage
      // back to a blank sign-up form is the worst outcome available here.
      //
      // Except at `home`, where there is no position to hold and nothing is
      // coming to move them. The picker is the safe landing -- an unapproved
      // driver is bounced off it the moment a read succeeds, and an approved
      // one can work from it.
      return here == NjRoutes.home ? NjRoutes.driverDirection : here;

    case DriverGate.cleared:
      // Approved, so the three gate screens stop existing — which is what
      // makes the design's "no back navigation" true without suppressing a
      // single pop.
      final online = session.valueOrNull?.online ?? false;

      if (online) {
        // The landing route is the feed. Only `home` and the gate screens
        // are redirected, so the driver can still walk back to the picker to
        // change direction or go offline.
        return here == NjRoutes.home || onGateScreen
            ? NjRoutes.driverFeed
            : here;
      }

      if (session is AsyncLoading) {
        // Mid-read. Nothing is decided yet, so nothing moves -- including at
        // `home`, which renders a spinner rather than a screen and exists for
        // exactly this moment.
        //
        // Moving to the picker here and back to the feed afterwards would
        // flicker; worse, it would mean bouncing an online driver OFF the
        // picker, which they are allowed to visit to change direction.
        return here;
      }

      // Offline, or the session could not be read at all. The picker either
      // way: it is where a heading is declared, and it is the screen that can
      // say a session read failed.
      return here == NjRoutes.driverFeed ||
              here == NjRoutes.home ||
              onGateScreen
          ? NjRoutes.driverDirection
          : here;
  }
}
