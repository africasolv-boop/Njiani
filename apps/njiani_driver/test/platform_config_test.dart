import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the platform configuration C6 depends on.
///
/// These keys are not reachable from Dart, so nothing else in the suite
/// notices when one goes missing -- and the failures they cause do not look
/// like missing configuration. Without `NSCameraUsageDescription` iOS
/// terminates the app the instant the camera opens, which reads as a crash in
/// the sign-up screen; without the `tel` query, Android 11+ reports that a
/// dialler which is plainly installed cannot be opened.
/// Matches a declared `<uses-permission>`, not a mention of its name.
///
/// The difference matters: this file's manifests carry comments explaining
/// which permissions are deliberately absent and why, and a substring match
/// on the bare name fails on the explanation.
Matcher containsPermission(String name) =>
    contains('<uses-permission android:name="android.permission.$name"');

void main() {
  /// The app package's own directory.
  ///
  /// `flutter test apps/njiani_driver` runs from the workspace root, while
  /// `flutter test` inside the package runs from the package -- and these
  /// files are found by path, not by import. Both are tried, and neither
  /// being there is reported as what it is rather than as a missing plist.
  Directory appRoot() {
    for (final candidate in ['.', 'apps/njiani_driver']) {
      final dir = Directory(candidate);
      if (File('${dir.path}/pubspec.yaml').existsSync() &&
          File('${dir.path}/pubspec.yaml')
              .readAsStringSync()
              .contains('name: njiani_driver')) {
        return dir;
      }
    }
    fail(
      'Could not find the njiani_driver package from '
      '${Directory.current.path}. Run this from the workspace root or from '
      'the package itself.',
    );
  }

  File file(String path) {
    final f = File('${appRoot().path}/$path');
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f;
  }


  group('iOS', () {
    late String plist;

    setUp(() => plist = file('ios/Runner/Info.plist').readAsStringSync());

    test('the camera has a usage description', () {
      expect(plist, contains('NSCameraUsageDescription'));
      expect(plist, contains('NSPhotoLibraryUsageDescription'));
    });

    test('the usage description says what the photo is for', () {
      // A description that does not name the licence is grounds for an App
      // Review rejection, and tells a driver nothing about why their camera
      // is being asked for.
      expect(plist.toLowerCase(), contains('licence'));
    });

    test('location has a usage description, when-in-use only', () {
      expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
      // `always` is a harder App Review conversation and a promise Njiani
      // would not be keeping: there is no reason to know where a driver is
      // with the app closed.
      //
      // Matched on the <key> element rather than the bare name, so a comment
      // explaining why a key is absent cannot make the assertion fail.
      expect(plist, isNot(contains('<key>NSLocationAlways')));
    });

    test('tel: is declared, for Call Njiani', () {
      expect(plist, contains('LSApplicationQueriesSchemes'));
      expect(plist, contains('<string>tel</string>'));
    });

    test('both languages are declared, and both have strings', () {
      expect(plist, contains('CFBundleLocalizations'));

      for (final lang in ['en', 'sw']) {
        final strings =
            file('ios/Runner/$lang.lproj/InfoPlist.strings').readAsStringSync();
        expect(
          strings,
          contains('NSCameraUsageDescription'),
          reason: '$lang is missing the camera prompt',
        );
        expect(
          strings,
          contains('NSPhotoLibraryUsageDescription'),
          reason: '$lang is missing the photo library prompt',
        );
        expect(
          strings,
          contains('NSLocationWhenInUseUsageDescription'),
          reason: '$lang is missing the location prompt',
        );
      }
    });

    test('the Kiswahili prompt is actually in Kiswahili', () {
      // Cheap, and it has caught a copy-paste before: a .lproj file holding
      // the English text ships an English prompt under a Kiswahili label,
      // which is worse than no translation because nothing looks wrong.
      final sw = file('ios/Runner/sw.lproj/InfoPlist.strings')
          .readAsStringSync()
          .toLowerCase();
      expect(sw, contains('leseni'));
      expect(sw, isNot(contains('driving licence')));
      expect(sw, contains('mahali ulipo'));
      expect(sw, isNot(contains('your location')));
    });
  });

  group('Android', () {
    late String manifest;

    setUp(() => manifest =
        file('android/app/src/main/AndroidManifest.xml').readAsStringSync());

    test('the dialler is queryable', () {
      expect(manifest, contains('android.intent.action.DIAL'));
      expect(manifest, contains('android:scheme="tel"'));
    });

    test('location is foreground only', () {
      expect(manifest, containsPermission('ACCESS_FINE_LOCATION'));
      expect(manifest, containsPermission('ACCESS_COARSE_LOCATION'));
      // Same reasoning as the iOS keys: no reason to know where a driver is
      // with the app closed, and a Play Console declaration to justify if we
      // asked.
      expect(manifest, isNot(containsPermission('ACCESS_BACKGROUND_LOCATION')));
    });

    test('no runtime permission is declared for the camera', () {
      // image_picker uses the system camera app via ACTION_IMAGE_CAPTURE, so
      // no CAMERA permission is needed. Declaring one would make the Play
      // listing claim an access this binary never uses.
      expect(manifest, isNot(containsPermission('CAMERA')));
    });
  });
}
