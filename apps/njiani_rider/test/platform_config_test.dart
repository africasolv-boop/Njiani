import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rider app's platform configuration.
///
/// The interesting assertions here are the negative ones. The two apps are
/// built from one codebase, so a key added to the driver app is one
/// copy-paste away from the rider app -- and a permission a binary does not
/// use is both an App Review rejection and a promise to the user that is not
/// kept.
void main() {
  /// The app package's own directory.
  ///
  /// `flutter test apps/njiani_rider` runs from the workspace root, while
  /// `flutter test` inside the package runs from the package -- and these
  /// files are found by path, not by import. Both are tried, and neither
  /// being there is reported as what it is rather than as a missing plist.
  Directory appRoot() {
    for (final candidate in ['.', 'apps/njiani_rider']) {
      final dir = Directory(candidate);
      if (File('${dir.path}/pubspec.yaml').existsSync() &&
          File('${dir.path}/pubspec.yaml')
              .readAsStringSync()
              .contains('name: njiani_rider')) {
        return dir;
      }
    }
    fail(
      'Could not find the njiani_rider package from '
      '${Directory.current.path}. Run this from the workspace root or from '
      'the package itself.',
    );
  }

  File file(String path) {
    final f = File('${appRoot().path}/$path');
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f;
  }


  test('tel: is declared, for the safety screen at C15', () {
    final plist = file('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>tel</string>'));
  });

  test('the rider app asks for no camera access', () {
    // A passenger never photographs a document. If this ever starts failing,
    // the question to ask is which screen needs a camera and why -- not how
    // to make the assertion pass.
    final plist = file('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('NSCameraUsageDescription')));
    expect(plist, isNot(contains('NSPhotoLibraryUsageDescription')));

    final manifest =
        file('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('android.permission.CAMERA')));
  });

  test('both languages are declared', () {
    final plist = file('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('CFBundleLocalizations'));
    expect(plist, contains('<string>sw</string>'));
  });
}
