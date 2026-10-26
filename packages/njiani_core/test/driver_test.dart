import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeDriverRepository drivers;
  late FakeLicenceCamera camera;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    drivers = FakeDriverRepository();
    camera = FakeLicenceCamera();
    // Every signed-in user has one: `handle_new_user` creates the row the
    // moment a number is verified, so a screen never sees a session without
    // a profile.
    profiles = FakeProfileRepository(
      profile: Profile(
        id: 'driver-1',
        phone: TzPhone.tryParse('712345678'),
        lang: NjLocale.en,
      ),
    );
  });

  tearDown(() {
    auth.dispose();
    drivers.dispose();
  });

  /// Signs in, so the controller builds against a real session.
  Future<void> signIn() =>
      auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);

  Future<void> pumpSignup(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await signIn();
    await pumpScreen(
      tester,
      const DriverSignupScreen(),
      auth: auth,
      driver: drivers,
      camera: camera,
      profile: profiles,
      locale: locale,
    );
  }

  /// Fills name and plate. The photo is attached separately, because the
  /// order and the failure of that step are what the tests are about.
  Future<void> fillDetails(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Juma Hassan');
    await tester.pump();
    // Deliberately not 'T 123 ABC': that is the bajaj hint text, so a finder
    // looking for it would match the placeholder as well as the typed value
    // and pass -- or fail -- for the wrong reason.
    await tester.enterText(fields.at(1), 't 999 zzz');
    await tester.pump();
  }

  NjButton submitButton(WidgetTester tester) => tester.widget<NjButton>(
        find.ancestor(
          of: find.text('Submit for review'),
          matching: find.byType(NjButton),
        ),
      );

  /// The number the auth state is carrying -- null unless one was typed in
  /// this session.
  TzPhone? typedPhoneOf(WidgetTester tester) =>
      authStateOf(tester, find.byType(DriverSignupScreen)).phone;

  /// The hint currently shown in the plate field.
  String? plateHint(WidgetTester tester) => tester
      .widget<TextField>(find.byType(TextField).at(1))
      .decoration
      ?.hintText;

  Future<void> attachPhoto(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(NjUploadBox));
    await tester.tap(find.byType(NjUploadBox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
  }

  // =========================================================================
  group('VehicleType — seats are a physical fact', () {
    test('a bajaj carries three and a boda one', () {
      expect(VehicleType.bajaj.seats, 3);
      expect(VehicleType.boda.seats, 1);
    });

    test('parses the database enum, and nothing else', () {
      expect(VehicleType.tryParse('bajaj'), VehicleType.bajaj);
      expect(VehicleType.tryParse('boda'), VehicleType.boda);
      expect(VehicleType.tryParse('tuktuk'), isNull);
      expect(VehicleType.tryParse(null), isNull);
    });
  });

  group('DriverStatus — the conservative direction', () {
    test('an unknown status is pending, never approved', () {
      // A status a future release adds must not read as approval in an old
      // binary. "Under review" is wrong but safe; "approved" is unsafe.
      expect(DriverStatus.parse('revoked'), DriverStatus.pending);
      expect(DriverStatus.parse(''), DriverStatus.pending);
      expect(DriverStatus.parse(null), DriverStatus.pending);
      expect(DriverStatus.parse('approved'), DriverStatus.approved);
    });

    test('only approved may drive', () {
      expect(
        DriverStatus.values.where((s) => s.canDrive),
        [DriverStatus.approved],
      );
    });
  });

  group('VehicleColour — one spelling of green', () {
    test('matches case-insensitively, so a hand-written row still renders', () {
      expect(VehicleColour.tryParse('Green'), VehicleColour.green);
      expect(VehicleColour.tryParse('green'), VehicleColour.green);
      expect(VehicleColour.tryParse('  GREEN '), VehicleColour.green);
      expect(VehicleColour.tryParse('Teal'), isNull);
    });
  });

  group('DriverApplication — the Submit rule, in one place', () {
    test('needs a name, a plate, a colour and a photo', () {
      const empty = DriverApplication();
      expect(empty.isComplete, isFalse);

      const noPhoto = DriverApplication(
        name: 'Juma Hassan',
        plate: 'T 123 ABC',
        colour: 'Green',
      );
      expect(noPhoto.isComplete, isFalse,
          reason: 'there is nothing for a person to review without the photo');

      expect(
        noPhoto.copyWith(licencePath: 'uid/licence.jpg').isComplete,
        isTrue,
      );
    });

    test('a plate is upper-cased and trimmed', () {
      const application = DriverApplication(plate: '  t 123 abc  ');
      expect(application.normalisedPlate, 'T 123 ABC');
    });

    test('a plate shorter than the database allows is incomplete', () {
      const short = DriverApplication(
        name: 'Juma Hassan',
        plate: 'T1',
        colour: 'Green',
        licencePath: 'uid/licence.jpg',
      );
      expect(short.isComplete, isFalse);
    });

    test('whitespace is not a name', () {
      const blank = DriverApplication(
        name: '   ',
        plate: 'T 123 ABC',
        colour: 'Green',
        licencePath: 'uid/licence.jpg',
      );
      expect(blank.isComplete, isFalse);
    });
  });

  group('Driver.fromRow', () {
    test('reads a row as the database writes it', () {
      final driver = Driver.fromRow(const {
        'profile_id': 'uid-1',
        'vehicle_type': 'boda',
        'plate': 'MC 777 QQ',
        'colour': 'Black',
        'status': 'rejected',
        'licence_path': 'uid-1/licence.jpg',
        'rejection_reason': 'Glare across the number.',
        'trips_count': 4,
        'created_at': '2026-10-26T08:00:00Z',
      });

      expect(driver.vehicleType, VehicleType.boda);
      expect(driver.seats, 1);
      expect(driver.status, DriverStatus.rejected);
      expect(driver.rejectionReason, 'Glare across the number.');
      expect(driver.tripsCount, 4);
    });

    test('a licence path is a path, not a URL', () {
      // Worth asserting: a URL here would mean the bucket was not private.
      final driver = Driver.fromRow(const {
        'profile_id': 'uid-1',
        'vehicle_type': 'bajaj',
        'plate': 'T 123 ABC',
        'colour': 'Green',
        'status': 'pending',
        'licence_path': 'uid-1/licence.jpg',
      });

      expect(driver.licencePath, isNot(startsWith('http')));
    });
  });

  // =========================================================================
  group('dSignup — the states in the spec', () {
    testWidgets('incomplete: Submit is disabled', (tester) async {
      await pumpSignup(tester);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('details without a photo: still disabled', (tester) async {
      await pumpSignup(tester);
      await fillDetails(tester);

      expect(
        submitButton(tester).onPressed,
        isNull,
        reason: 'the photo is the only thing a person can actually check',
      );
    });

    testWidgets('details and a photo: enabled', (tester) async {
      await pumpSignup(tester);
      await fillDetails(tester);
      await attachPhoto(tester);

      expect(submitButton(tester).onPressed, isNotNull);
      expect(
        tester.widget<NjUploadBox>(find.byType(NjUploadBox)).state,
        NjUploadState.done,
      );
    });

    testWidgets('the plate is upper-cased as it is typed', (tester) async {
      await pumpSignup(tester);
      await tester.enterText(find.byType(TextField).at(1), 't 999 zzz');
      await tester.pump();

      expect(find.text('T 999 ZZZ'), findsOneWidget);
    });

    testWidgets('the verified number is shown, and cannot be edited',
        (tester) async {
      await pumpSignup(tester);

      expect(find.text('+255 712 345 678'), findsOneWidget);
      // Two editable fields on this screen: name and plate. The phone number
      // is not one of them -- offering it as editable would invite a driver
      // to type a different number and wonder why no SMS arrives.
      expect(find.byType(TextField), findsNWidgets(2));
    });

    // A returning driver has a session but no AuthState.phone -- that is only
    // set by typing a number in the current session. The durable record is
    // the profile, and reading it is what keeps this field filled after a
    // restart.
    testWidgets('the number survives a restart, read from the profile',
        (tester) async {
      await pumpSignup(tester);
      expect(typedPhoneOf(tester), isNull, reason: 'no number typed this session');
      expect(find.text('+255 712 345 678'), findsOneWidget);
    });

    testWidgets('no profile yet leaves the field blank, not broken',
        (tester) async {
      // The few hundred milliseconds on a brand-new account before the
      // trigger's row is readable.
      profiles.profile = null;
      await pumpSignup(tester);

      expect(find.byType(DriverSignupScreen), findsOneWidget);
      expect(find.text('+255 712 345 678'), findsNothing);
    });

    // The failure the design calls out by name.
    testWidgets('upload failed: the box says so and the details are kept',
        (tester) async {
      drivers.uploadFailure = const DriverError(DriverFailure.uploadFailed);

      await pumpSignup(tester);
      await fillDetails(tester);
      await attachPhoto(tester);

      expect(
        tester.widget<NjUploadBox>(find.byType(NjUploadBox)).state,
        NjUploadState.failed,
      );
      expect(
        find.text("Photo didn't upload. Your details are saved."),
        findsWidgets,
      );
      // The point of the whole arrangement: the typed details survived.
      expect(find.text('Juma Hassan'), findsOneWidget);
      expect(find.text('T 999 ZZZ'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('a failed upload can be retried on its own', (tester) async {
      drivers.uploadFailure = const DriverError(DriverFailure.uploadFailed);

      await pumpSignup(tester);
      await fillDetails(tester);
      await attachPhoto(tester);

      drivers.uploadFailure = null;
      await attachPhoto(tester);

      expect(
        tester.widget<NjUploadBox>(find.byType(NjUploadBox)).state,
        NjUploadState.done,
      );
      expect(submitButton(tester).onPressed, isNotNull);
      expect(drivers.uploads, hasLength(1));
    });

    testWidgets('a photo too large is reported as such, not as a failure',
        (tester) async {
      // Storage enforces the 5 MB cap, so this is the server's answer. It
      // needs its own wording: "didn't upload" tells a driver to try again
      // with the same photo, which will fail again.
      drivers.uploadFailure = const DriverError(DriverFailure.photoRejected);

      await pumpSignup(tester);
      await attachPhoto(tester);

      expect(
        find.text(
          'That photo was too large or not a picture. '
          'Take a new one with the camera.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('backing out of the camera is not a failure', (tester) async {
      camera.cancelled = true;

      await pumpSignup(tester);
      await attachPhoto(tester);

      expect(
        tester.widget<NjUploadBox>(find.byType(NjUploadBox)).state,
        NjUploadState.empty,
        reason: 'nothing went wrong, so nothing should say it did',
      );
      expect(drivers.uploads, isEmpty);
    });

    testWidgets('backing out after a successful photo keeps the photo',
        (tester) async {
      await pumpSignup(tester);
      await attachPhoto(tester);

      camera.cancelled = true;
      await attachPhoto(tester);

      expect(
        tester.widget<NjUploadBox>(find.byType(NjUploadBox)).state,
        NjUploadState.done,
      );
    });

    testWidgets('submitting files the application as pending', (tester) async {
      await pumpSignup(tester);
      await fillDetails(tester);
      await attachPhoto(tester);

      // The form is taller than a phone screen, so Submit has to be brought
      // into view before it can be tapped -- exactly as a driver scrolls to
      // it.
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(drivers.submissions, hasLength(1));
      expect(drivers.submissions.single.normalisedPlate, 'T 999 ZZZ');
      expect(drivers.driver?.status, DriverStatus.pending);
      // The name is a property of the person, so it goes on the profile --
      // a passenger sees it at C10 when the match is made.
      expect(profiles.nameWrites, ['Juma Hassan']);
    });

    testWidgets('the vehicle type changes the plate placeholder',
        (tester) async {
      await pumpSignup(tester);
      expect(plateHint(tester), 'T 123 ABC');

      await tester.tap(find.text('Boda · 1 seat'));
      await tester.pumpAndSettle();

      expect(plateHint(tester), 'MC 123 AB');
    });

    testWidgets('renders in Kiswahili', (tester) async {
      await pumpSignup(tester, locale: NjLocale.sw);

      expect(find.text('Endesha na Njiani'), findsOneWidget);
      expect(find.text('Tuma kwa uhakiki'), findsOneWidget);
      expect(find.text('Picha ya leseni ya udereva'), findsOneWidget);
    });
  });

  // =========================================================================
  group('dPending', () {
    Driver pending() => const Driver(
          profileId: 'driver-1',
          vehicleType: VehicleType.bajaj,
          plate: 'T 123 ABC',
          colour: 'Green',
          status: DriverStatus.pending,
          licencePath: 'driver-1/licence.jpg',
        );

    testWidgets('shows what was submitted, so it can be read back',
        (tester) async {
      drivers.driver = pending();
      await signIn();
      await pumpScreen(
        tester,
        const DriverPendingScreen(),
        auth: auth,
        driver: drivers,
        locale: NjLocale.en,
      );

      expect(find.text("We're checking your documents"), findsOneWidget);
      expect(find.byType(NjPlateBadge), findsOneWidget);
      expect(
        tester.widget<NjPlateBadge>(find.byType(NjPlateBadge)).plate,
        'T 123 ABC',
      );
      // The colour is localised for display, while 'Green' is what is stored.
      expect(find.textContaining('Green'), findsOneWidget);
    });

    testWidgets('the stored colour is localised, not echoed', (tester) async {
      drivers.driver = pending();
      await signIn();
      await pumpScreen(
        tester,
        const DriverPendingScreen(),
        auth: auth,
        driver: drivers,
        // Kiswahili is pumpScreen's default. Left implicit because passing it
        // trips avoid_redundant_argument_values -- and if that default ever
        // changes, the assertion below is what says so.
      );

      expect(find.textContaining('Kijani'), findsOneWidget);
      expect(find.textContaining('Green'), findsNothing);
    });

    testWidgets('suspended says so, and offers a way out', (tester) async {
      drivers.driver = pending().copyWith(status: DriverStatus.suspended);
      await signIn();
      await pumpScreen(
        tester,
        const DriverPendingScreen(suspended: true),
        auth: auth,
        driver: drivers,
        locale: NjLocale.en,
      );

      expect(find.text('Your account is on hold'), findsOneWidget);
      expect(find.text("We're checking your documents"), findsNothing);
      // Never leaves a suspended driver without a next step, even with no
      // SUPPORT_PHONE compiled in -- Check again is always there.
      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('pull to refresh re-reads the row', (tester) async {
      // Worth its own test: the screen is short enough to fit without
      // scrolling, and a RefreshIndicator over a scroll view that cannot
      // overscroll recognises no gesture at all.
      drivers.driver = pending();
      await signIn();
      await pumpScreen(
        tester,
        const DriverPendingScreen(),
        auth: auth,
        driver: drivers,
        locale: NjLocale.en,
      );

      drivers.driver = pending().copyWith(status: DriverStatus.approved);

      await tester.fling(
        find.byType(DriverPendingScreen),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        driverStateOf(tester, find.byType(DriverPendingScreen))
            .valueOrNull
            ?.status,
        DriverStatus.approved,
      );
    });

    testWidgets('Check again re-reads the row', (tester) async {
      drivers.driver = pending();
      await signIn();
      await pumpScreen(
        tester,
        const DriverPendingScreen(),
        auth: auth,
        driver: drivers,
        locale: NjLocale.en,
      );

      // An admin decides, elsewhere, with no realtime event delivered --
      // the socket died while the app was backgrounded.
      drivers.driver = pending().copyWith(
        status: DriverStatus.rejected,
        rejectionReason: 'Glare across the number.',
      );

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(
        driverStateOf(tester, find.byType(DriverPendingScreen)).valueOrNull
            ?.status,
        DriverStatus.rejected,
      );
    });
  });

  // =========================================================================
  group('dRejected', () {
    Driver rejected() => const Driver(
          profileId: 'driver-1',
          vehicleType: VehicleType.bajaj,
          plate: 'T 123 ABC',
          colour: 'Green',
          status: DriverStatus.rejected,
          licencePath: 'driver-1/licence.jpg',
          rejectionReason: 'Glare across the number. Take it again in shade.',
        );

    Future<void> pumpRejected(
      WidgetTester tester, {
      NjLocale locale = NjLocale.en,
    }) async {
      drivers.driver = rejected();
      await signIn();
      await pumpScreen(
        tester,
        const DriverRejectedScreen(),
        auth: auth,
        driver: drivers,
        camera: camera,
        locale: locale,
      );
    }

    testWidgets('leads with the reason a person wrote', (tester) async {
      await pumpRejected(tester);

      expect(
        find.text('Glare across the number. Take it again in shade.'),
        findsOneWidget,
      );
      expect(find.text('One thing to fix'), findsOneWidget);
    });

    // The checklist is the promise that resubmit_driver_licence() keeps.
    testWidgets('shows what is still accepted, not just what failed',
        (tester) async {
      await pumpRejected(tester);

      final rows = tester
          .widgetList<NjStatusRow>(find.byType(NjStatusRow))
          .toList();

      expect(rows, hasLength(3));
      expect(rows.where((r) => r.tone == NjStatusTone.good), hasLength(2));
      expect(rows.where((r) => r.tone == NjStatusTone.bad), hasLength(1));
      expect(rows.last.label, 'Licence photo');
    });

    testWidgets('retaking the photo re-queues the application', (tester) async {
      await pumpRejected(tester);

      await tester.tap(find.text('Take the photo again'));
      await tester.pumpAndSettle();

      expect(drivers.uploads, hasLength(1));
      expect(drivers.driver?.status, DriverStatus.pending);
      // "Re-submission does not reset the other checks."
      expect(drivers.driver?.plate, 'T 123 ABC');
      expect(drivers.driver?.colour, 'Green');
      expect(drivers.driver?.rejectionReason, isNull);
    });

    testWidgets('backing out of the camera does not re-queue anything',
        (tester) async {
      camera.cancelled = true;
      await pumpRejected(tester);

      await tester.tap(find.text('Take the photo again'));
      await tester.pumpAndSettle();

      expect(drivers.uploads, isEmpty);
      expect(
        drivers.driver?.status,
        DriverStatus.rejected,
        reason: 're-queueing with the same unreadable photo would get the '
            'driver rejected twice with no idea why',
      );
    });

    testWidgets('a failed upload does not re-queue either', (tester) async {
      drivers.uploadFailure = const DriverError(DriverFailure.uploadFailed);
      await pumpRejected(tester);

      await tester.tap(find.text('Take the photo again'));
      await tester.pumpAndSettle();

      expect(drivers.driver?.status, DriverStatus.rejected);
      expect(
        find.text("Photo didn't upload. Your details are saved."),
        findsOneWidget,
      );
    });

    testWidgets('renders in Kiswahili', (tester) async {
      await pumpRejected(tester, locale: NjLocale.sw);

      expect(find.text('Kitu kimoja cha kurekebisha'), findsOneWidget);
      expect(find.text('Piga picha tena'), findsOneWidget);
      expect(find.text('Imekataliwa'), findsOneWidget);
    });
  });

  // =========================================================================
  group('the gate decision, in one function', () {
    test('a failed read holds position instead of guessing', () {
      // The worst outcome available here is sending an approved driver back
      // to a blank sign-up form because their data dropped out at a stage.
      expect(
        driverGateFor(AsyncError(Exception('offline'), StackTrace.empty)),
        DriverGate.unknown,
      );
      expect(driverGateFor(const AsyncLoading()), DriverGate.unknown);
    });

    test('maps every status to a screen', () {
      Driver withStatus(DriverStatus status) => Driver(
            profileId: 'd',
            vehicleType: VehicleType.bajaj,
            plate: 'T 123 ABC',
            colour: 'Green',
            status: status,
          );

      expect(driverGateFor(const AsyncData(null)), DriverGate.signUp);
      expect(
        driverGateFor(AsyncData(withStatus(DriverStatus.pending))),
        DriverGate.pending,
      );
      expect(
        driverGateFor(AsyncData(withStatus(DriverStatus.rejected))),
        DriverGate.rejected,
      );
      expect(
        driverGateFor(AsyncData(withStatus(DriverStatus.suspended))),
        DriverGate.suspended,
      );
      expect(
        driverGateFor(AsyncData(withStatus(DriverStatus.approved))),
        DriverGate.cleared,
      );
    });
  });

  group('FakeLicenceCamera', () {
    test('hands back bytes without touching a plugin', () async {
      final photo = await FakeLicenceCamera().takePhoto();
      expect(photo, isNotNull);
      expect(photo!.bytes, isA<Uint8List>());
      expect(photo.contentType, startsWith('image/'));
    });
  });
}
