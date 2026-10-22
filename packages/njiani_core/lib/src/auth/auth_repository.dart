import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_failure.dart';
import 'tz_phone.dart';

/// Sending and verifying the SMS code.
///
/// An interface so the screens can be driven by a fake in tests. Every real
/// send costs money, so there is exactly one implementation that spends it.
abstract interface class AuthRepository {
  /// Whether somebody is signed in right now.
  bool get isSignedIn;

  /// The signed-in user's id, or null.
  String? get userId;

  /// Fires whenever the session appears or disappears.
  Stream<bool> get signedInChanges;

  /// Asks the backend to send a code to [phone].
  ///
  /// Returns null on success, or why it failed.
  Future<AuthError?> sendCode(TzPhone phone);

  /// Exchanges [code] for a session.
  Future<AuthError?> verifyCode(TzPhone phone, String code);

  /// Ends the session.
  Future<void> signOut();
}

/// The real one, backed by Supabase Auth phone sign-in.
///
/// Supabase generates and verifies the code itself and issues the session;
/// the Send-SMS auth hook only delivers it (see
/// `supabase/functions/send-sms-hook`). That split matters: nothing in this
/// app, and nothing in Beem, ever decides whether a code was correct.
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  @override
  Future<AuthError?> sendCode(TzPhone phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone.e164);
      return null;
    } on AuthException catch (error) {
      return classifySend(error);
    } catch (error) {
      return AuthError(AuthFailure.offline, detail: error.toString());
    }
  }

  @override
  Future<AuthError?> verifyCode(TzPhone phone, String code) async {
    try {
      await _client.auth.verifyOTP(
        phone: phone.e164,
        token: code,
        type: OtpType.sms,
      );
      return null;
    } on AuthException catch (error) {
      return classifyVerify(error);
    } catch (error) {
      return AuthError(AuthFailure.offline, detail: error.toString());
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  /// Failures that can happen while **asking** for a code.
  ///
  /// Deliberately narrow. The client has already checked the number, so a
  /// failure here is the project's configuration, the rate limiter, or
  /// something we have not seen before -- never the digit count. Guessing
  /// "your number is wrong" from a message that merely contains the word
  /// "phone" is what made a disabled provider look like a typo.
  @visibleForTesting
  static AuthError classifySend(AuthException error) {
    final message = error.message.toLowerCase();

    if (error.statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('too many') ||
        message.contains('security purposes')) {
      return AuthError(AuthFailure.rateLimited, detail: error.message);
    }

    // Phone sign-in off, no SMS provider, or the hook rejecting the call.
    if (message.contains('disabled') ||
        message.contains('not enabled') ||
        message.contains('unsupported') ||
        message.contains('provider') ||
        message.contains('sms') ||
        message.contains('hook')) {
      return AuthError(AuthFailure.providerDisabled, detail: error.message);
    }

    return AuthError(AuthFailure.unknown, detail: error.message);
  }

  /// Failures that can happen while **submitting** a code.
  @visibleForTesting
  static AuthError classifyVerify(AuthException error) {
    final message = error.message.toLowerCase();

    if (error.statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('too many')) {
      return AuthError(AuthFailure.rateLimited, detail: error.message);
    }
    if (message.contains('expired')) {
      return AuthError(AuthFailure.expiredCode, detail: error.message);
    }
    // On this path "invalid" really does mean the token: the only thing being
    // submitted is the code.
    if (message.contains('invalid') ||
        message.contains('incorrect') ||
        message.contains('token')) {
      return AuthError(AuthFailure.wrongCode, detail: error.message);
    }
    return AuthError(AuthFailure.unknown, detail: error.message);
  }
}

/// Used when this build has no Supabase credentials.
///
/// Reports [AuthFailure.notConfigured] rather than pretending to work, so the
/// screen can say which key is missing instead of looking broken.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository({this.reason});

  /// What specifically is wrong, when something is.
  ///
  /// Carried through to the screen so a misconfiguration names itself instead
  /// of showing a generic "not configured".
  final String? reason;

  @override
  bool get isSignedIn => false;

  @override
  String? get userId => null;

  @override
  Stream<bool> get signedInChanges => const Stream<bool>.empty();

  @override
  Future<AuthError?> sendCode(TzPhone phone) async =>
      AuthError(AuthFailure.notConfigured, detail: reason);

  @override
  Future<AuthError?> verifyCode(TzPhone phone, String code) async =>
      AuthError(AuthFailure.notConfigured, detail: reason);

  @override
  Future<void> signOut() async {}
}
