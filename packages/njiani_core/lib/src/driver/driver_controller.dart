import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../data/supabase_client.dart';
import '../profile/profile_controller.dart';
import 'driver.dart';
import 'driver_repository.dart';
import 'licence_camera.dart';

/// Supplies the [DriverRepository].
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client == null) {
    final fake = FakeDriverRepository();
    ref.onDispose(fake.dispose);
    return fake;
  }
  return SupabaseDriverRepository(client);
});

/// The signed-in driver's application, or null if they have never filed one.
///
/// Null is the signal the router reads to show sign-up, so it is a state and
/// not an error. Only the driver app watches this; the rider app never builds
/// it.
class DriverController extends AsyncNotifier<Driver?> {
  @override
  Future<Driver?> build() async {
    final signedIn = ref.watch(authProvider).step == AuthStep.signedIn;
    if (!signedIn) return null;

    // The approval arrives here, without the driver doing anything. "A driver
    // should never have to reinstall to discover they were approved."
    final subscription = _repository.watch().listen(
          (driver) => state = AsyncData(driver),
          onError: (Object error) {
            // A dropped socket is not a reason to blank the screen: the row
            // already in `state` is still the truth as last read, and
            // `refresh()` on resume is the fallback.
            debugPrint('[njiani] driver stream: $error');
          },
        );
    ref.onDispose(subscription.cancel);

    return _repository.load();
  }

  DriverRepository get _repository => ref.read(driverRepositoryProvider);

  /// Takes a photo and uploads it, returning its path in the bucket.
  ///
  /// Null when the driver backed out of the camera. Throws [DriverError] when
  /// the upload fails -- which the screen renders as its own state, because
  /// the whole point is that a failed photo does not cost the driver the
  /// details they typed.
  Future<String?> captureLicence({bool fromGallery = false}) async {
    final camera = ref.read(licenceCameraProvider);
    final photo =
        fromGallery ? await camera.pickPhoto() : await camera.takePhoto();
    if (photo == null) return null;

    return _repository.uploadLicence(
      bytes: photo.bytes,
      contentType: photo.contentType,
    );
  }

  /// Files the application, and writes the name onto the profile.
  ///
  /// The name goes to `profiles.display_name` rather than onto `drivers`,
  /// because it is a property of the person, not the vehicle -- a passenger
  /// sees it at C10 when the match is made.
  Future<Driver> submit(DriverApplication application) async {
    final filed = await _repository.submit(application);
    state = AsyncData(filed);

    // Deliberately after the application is filed, and deliberately not
    // fatal. The row is what a person reviews; a missing display name is a
    // cosmetic gap that the next write fixes, and failing the whole
    // submission over it would send the driver back to a filled-in form with
    // nothing to change.
    try {
      await ref.read(profileProvider.notifier).setDisplayName(
            application.normalisedName,
          );
    } catch (error) {
      debugPrint('[njiani] could not write display_name: $error');
    }

    return filed;
  }

  /// Replaces the photo on a rejected application and returns to the queue.
  Future<Driver> resubmitLicence(String licencePath) async {
    final requeued = await _repository.resubmitLicence(licencePath);
    state = AsyncData(requeued);
    return requeued;
  }

  /// Re-reads the row from the server.
  ///
  /// The fallback behind the realtime subscription, for a socket that died
  /// while the app was backgrounded. The pending screen calls it on resume
  /// and on a pull-to-refresh.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _repository.load());
    } on DriverError catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

/// The signed-in driver's application.
final driverProvider =
    AsyncNotifierProvider<DriverController, Driver?>(DriverController.new);

/// Which C6 screen the driver belongs on, or null to let them through.
///
/// One function, so the router's gate and any screen that needs to reason
/// about the same question cannot disagree. Returns null for a driver who may
/// drive, which the router reads as "no redirect".
DriverGate driverGateFor(AsyncValue<Driver?> driver) => switch (driver) {
      // Still reading. Resolves on its own, so nothing moves.
      AsyncLoading() => DriverGate.loading,
      // A failed read is not a reason to show sign-up to a driver who already
      // applied. Sending an approved driver back to a blank form, because
      // their data dropped out at a stage, is the worst outcome available
      // here -- so an error waits rather than guessing.
      //
      // Kept distinct from `loading`, which is the whole point: one of them
      // is going to answer and the other is not. Collapsing them meant the
      // router treated a cold start exactly like a dead connection.
      AsyncError() => DriverGate.unreadable,
      AsyncData(value: null) => DriverGate.signUp,
      AsyncData(value: final row) => switch (row!.status) {
          DriverStatus.pending => DriverGate.pending,
          DriverStatus.rejected => DriverGate.rejected,
          DriverStatus.suspended => DriverGate.suspended,
          DriverStatus.approved => DriverGate.cleared,
        },
      _ => DriverGate.loading,
    };

/// Where the driver-approval gate sends a driver.
enum DriverGate {
  /// Still reading. The router holds position; this answers itself.
  loading,

  /// The read failed. The router holds position too -- except where there is
  /// no position to hold, because nothing is coming to move it.
  unreadable,

  /// No application on file.
  signUp,

  /// Under review.
  pending,

  /// Rejected, with a reason to act on.
  rejected,

  /// Was approved, now suspended. Same screen as pending, different words.
  suspended,

  /// Approved. The gate is open.
  cleared,
}
