import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How a Supabase error is turned into something the screen can say.
///
/// These exist because the first version of this classifier guessed
/// `invalidPhone` from any message containing the word "phone". A project
/// with phone sign-in switched off therefore told the user "Enter 9 digits,
/// without the leading zero" — about a number that was already correct. The
/// rule now is simple: **a send failure is never about the digits**, because
/// the client checked them before calling.
void main() {
  AuthError send(String message, {String? status}) =>
      SupabaseAuthRepository.classifySend(
        AuthException(message, statusCode: status),
      );

  AuthError verify(String message, {String? status}) =>
      SupabaseAuthRepository.classifyVerify(
        AuthException(message, statusCode: status),
      );

  group('asking for a code', () {
    test('a disabled provider is never reported as a bad number', () {
      // The exact regression. Every one of these contains "phone".
      const messages = [
        'Phone logins are disabled',
        'Signups not allowed for otp',
        'Unsupported phone provider',
        'Error sending confirmation OTP to provider',
        'Failed to send sms: hook returned 401',
      ];
      for (final message in messages) {
        final error = send(message);
        expect(
          error.kind,
          isNot(AuthFailure.invalidPhone),
          reason: '"$message" is a project setting, not a typo',
        );
      }
    });

    test('a disabled provider says so, and names the setting', () {
      expect(send('Phone logins are disabled').kind,
          AuthFailure.providerDisabled);
      expect(send('Unsupported phone provider').kind,
          AuthFailure.providerDisabled);
      expect(send('Error sending sms').kind, AuthFailure.providerDisabled);
    });

    test('a rate limit is recognised by status and by wording', () {
      expect(send('anything', status: '429').kind, AuthFailure.rateLimited);
      expect(send('Email rate limit exceeded').kind, AuthFailure.rateLimited);
      expect(
        send('For security purposes, you can only request this after 54s')
            .kind,
        AuthFailure.rateLimited,
      );
    });

    test('anything unrecognised is unknown, not invented', () {
      expect(send('Something nobody has seen before').kind,
          AuthFailure.unknown);
    });

    test('the provider message is always kept', () {
      // A classifier that throws the message away cannot be debugged.
      expect(send('Phone logins are disabled').detail,
          'Phone logins are disabled');
      expect(send('Mystery').detail, 'Mystery');
    });
  });

  group('submitting a code', () {
    test('"invalid" here really does mean the token', () {
      // On this path the only thing submitted is the code, so the word is
      // unambiguous — unlike on the send path.
      expect(verify('Token has expired or is invalid').kind,
          AuthFailure.expiredCode);
      expect(verify('Invalid token').kind, AuthFailure.wrongCode);
      expect(verify('Incorrect code').kind, AuthFailure.wrongCode);
    });

    test('expired beats wrong, because the fix is different', () {
      // Expired offers a resend; wrong does not.
      expect(verify('OTP expired').kind, AuthFailure.expiredCode);
    });

    test('a rate limit is still a rate limit', () {
      expect(verify('too many requests', status: '429').kind,
          AuthFailure.rateLimited);
    });

    test('anything unrecognised is unknown', () {
      expect(verify('Unheard of').kind, AuthFailure.unknown);
      expect(verify('Unheard of').detail, 'Unheard of');
    });
  });

  group('AuthError', () {
    test('compares by value', () {
      expect(const AuthError(AuthFailure.offline, detail: 'x'),
          const AuthError(AuthFailure.offline, detail: 'x'));
      expect(const AuthError(AuthFailure.offline),
          isNot(const AuthError(AuthFailure.unknown)));
    });

    test('knows whether it has anything to show', () {
      expect(const AuthError(AuthFailure.offline).hasDetail, isFalse);
      expect(const AuthError(AuthFailure.offline, detail: '').hasDetail,
          isFalse);
      expect(const AuthError(AuthFailure.offline, detail: 'x').hasDetail,
          isTrue);
    });
  });
}
