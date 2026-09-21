import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  group('AppConfig', () {
    test('defaults to the local environment', () {
      expect(AppConfig.environment, 'local');
    });

    test('reports no backend when credentials are absent', () {
      // C0 ships with an empty .env.local, so this must hold until C3.
      expect(AppConfig.hasSupabase, isFalse);
    });

    test('every entry names a component and a purpose', () {
      expect(AppConfig.entries, isNotEmpty);
      for (final entry in AppConfig.entries) {
        expect(entry.key, isNotEmpty);
        expect(entry.neededAt, matches(RegExp(r'^C\d+$')));
        expect(entry.purpose, isNotEmpty);
      }
    });

    test('entry keys are unique', () {
      final keys = AppConfig.entries.map((e) => e.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('an unset entry displays as "not set", never as empty', () {
      const entry = ConfigEntry(
        key: 'X',
        value: '',
        neededAt: 'C3',
        purpose: 'test',
      );
      expect(entry.isSet, isFalse);
      expect(entry.display, 'not set');
    });

    test('a secret entry never reveals its value', () {
      const secret = ConfigEntry(
        key: 'X',
        value: 'super-secret-token',
        neededAt: 'C3',
        purpose: 'test',
        secret: true,
      );
      expect(secret.isSet, isTrue);
      expect(secret.display, isNot(contains('super-secret-token')));
      expect(secret.display, contains('set'));
    });
  });

  group('NjianiApp', () {
    test('the two apps have distinct bundle ids', () {
      expect(NjianiApp.rider.bundleId, 'tz.njiani.rider');
      expect(NjianiApp.driver.bundleId, 'tz.njiani.driver');
      expect(NjianiApp.rider.bundleId, isNot(NjianiApp.driver.bundleId));
    });

    test('bundle ids are App Store safe', () {
      // Apple rejects underscores in bundle identifiers.
      for (final app in NjianiApp.values) {
        expect(app.bundleId, matches(RegExp(r'^[a-zA-Z0-9.\-]+$')));
      }
    });

    test('every app carries both languages', () {
      for (final app in NjianiApp.values) {
        expect(app.label, isNotEmpty);
        expect(app.tagline, isNotEmpty);
        expect(app.taglineSw, isNotEmpty);
        expect(app.taglineSw, isNot(app.tagline));
      }
    });

    test('role helpers agree with the enum', () {
      expect(NjianiApp.rider.isRider, isTrue);
      expect(NjianiApp.rider.isDriver, isFalse);
      expect(NjianiApp.driver.isDriver, isTrue);
      expect(NjianiApp.driver.isRider, isFalse);
    });
  });
}
