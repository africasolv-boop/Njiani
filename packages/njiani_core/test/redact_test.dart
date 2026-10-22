import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// These exist because a debug line that echoed a provider's error message
/// verbatim put a live Postgres password on screen. The project had been
/// configured with a database connection string where the API URL belongs,
/// and the client quoted the whole URI back in its complaint — which then
/// travelled into a screenshot.
///
/// Diagnostics are worth having. No diagnostic is worth a credential.
void main() {
  group('redactSecrets', () {
    test('masks the password in a database URI', () {
      const message = "Unsupported scheme 'postgresql' in URI "
          'postgresql://postgres:Pa55wordExample@db.abcdefgh.supabase.co:5432/postgres';
      final safe = redactSecrets(message);

      expect(safe, isNot(contains('Pa55wordExample')));
      expect(safe, contains('••••••'));
      // The shape survives, so the mistake is still diagnosable.
      expect(safe, contains('postgresql://postgres:'));
      expect(safe, contains('db.abcdefgh.supabase.co'));
    });

    test('masks a password in any scheme', () {
      for (final scheme in ['postgres', 'postgresql', 'https', 'redis']) {
        final safe = redactSecrets('$scheme://user:hunter2@host/path');
        expect(safe, isNot(contains('hunter2')), reason: scheme);
      }
    });

    test('masks a JWT', () {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NSIsInJvbGUiOiJhbm9uIn0.abcdefghijklmnop';
      final safe = redactSecrets('Invalid key: $jwt');

      expect(safe, isNot(contains('eyJhbGci')));
      expect(safe, contains('«token»'));
    });

    test('masks the newer Supabase key formats', () {
      expect(redactSecrets('key sb_publishable_AbC123xyz'),
          isNot(contains('AbC123xyz')));
      expect(redactSecrets('key sb_secret_AbC123xyz'),
          isNot(contains('AbC123xyz')));
    });

    test('masks a webhook signing secret', () {
      final safe = redactSecrets('secret v1,whsec_QUJDREVGR0hJSktMTU5PUA==');
      expect(safe, isNot(contains('QUJDREVGR0hJSktMTU5PUA')));
      expect(safe, contains('whsec_••••••'));
    });

    test('masks a bearer token', () {
      final safe = redactSecrets('Authorization: Bearer abc123def456ghi789');
      expect(safe, isNot(contains('abc123def456ghi789')));
    });

    test('leaves ordinary messages alone', () {
      const plain = 'Phone logins are disabled';
      expect(redactSecrets(plain), plain);
      expect(redactSecrets('Gateway Timeout'), 'Gateway Timeout');
      // A URL with no credentials is not a secret.
      expect(redactSecrets('https://abcdefgh.supabase.co/auth/v1/otp'),
          contains('abcdefgh.supabase.co'));
    });

    test('handles empty and null', () {
      expect(redactSecrets(null), '');
      expect(redactSecrets(''), '');
    });
  });

  group('AppConfig.supabaseUrlProblem', () {
    test('a build with no URL has no problem to report', () {
      // Tests run without dart-defines, so this is the unset case.
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseUrlProblem, isNull);
      expect(AppConfig.hasSupabase, isFalse);
      expect(AppConfig.isUsable, isFalse);
    });
  });

  group('ConfigEntry.display', () {
    test('a key collapses to a fingerprint', () {
      const entry = ConfigEntry(
        key: 'SUPABASE_ANON_KEY',
        value: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig',
        neededAt: 'C3',
        purpose: 'key',
        secret: true,
      );
      expect(entry.display, isNot(contains('eyJhbGci')));
      expect(entry.display, contains('set'));
    });

    test('a URL is shown, but with any credentials masked', () {
      // Hiding it outright would make a pasted connection string invisible,
      // which is the mistake this is meant to reveal.
      const entry = ConfigEntry(
        key: 'SUPABASE_URL',
        value: 'postgresql://postgres:Pa55wordExample@db.abc.supabase.co:5432/postgres',
        neededAt: 'C3',
        purpose: 'url',
      );
      expect(entry.display, isNot(contains('Pa55wordExample')));
      expect(entry.display, contains('postgresql://'));
      expect(entry.display, contains('db.abc.supabase.co'));
    });

    test('a correct API URL is shown in full', () {
      const entry = ConfigEntry(
        key: 'SUPABASE_URL',
        value: 'https://abcdefgh.supabase.co',
        neededAt: 'C3',
        purpose: 'url',
      );
      expect(entry.display, 'https://abcdefgh.supabase.co');
    });
  });

  group('UnconfiguredAuthRepository', () {
    test('carries the reason so the screen can name it', () async {
      const repository = UnconfiguredAuthRepository(
        reason: 'SUPABASE_URL holds a database connection string.',
      );
      final error = await repository.sendCode(TzPhone.tryParse('712345678')!);

      expect(error?.kind, AuthFailure.notConfigured);
      expect(error?.detail, contains('connection string'));
    });

    test('is happy with no reason at all', () async {
      const repository = UnconfiguredAuthRepository();
      final error = await repository.sendCode(TzPhone.tryParse('712345678')!);

      expect(error?.kind, AuthFailure.notConfigured);
      expect(error?.detail, isNull);
    });
  });
}
