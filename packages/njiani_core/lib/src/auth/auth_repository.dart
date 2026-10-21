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
  Future<AuthFailure?> sendCode(TzPhone phone);

  /// Exchanges [code] for a session.
  Future<AuthFailure?> verifyCode(TzPhone phone, String code);

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
  Future<AuthFailure?> sendCode(TzPhone phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone.e164);
      return null;
    } on AuthException catch (error) {
      return _classify(error);
    } catch (_) {
      return AuthFailure.offline;
    }
  }

  @override
  Future<AuthFailure?> verifyCode(TzPhone phone, String code) async {
    try {
      await _client.auth.verifyOTP(
        phone: phone.e164,
        token: code,
        type: OtpType.sms,
      );
      return null;
    } on AuthException catch (error) {
      return _classify(error);
    } catch (_) {
      return AuthFailure.offline;
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  /// Maps a Supabase error onto something the screen can say in two languages.
  ///
  /// Matches on the status code first and the message only as a fallback,
  /// because the wording is not part of anyone's API contract.
  static AuthFailure _classify(AuthException error) {
    if (error.statusCode == '429') return AuthFailure.rateLimited;

    final message = error.message.toLowerCase();
    if (message.contains('expired')) return AuthFailure.expiredCode;
    if (message.contains('invalid') || message.contains('incorrect')) {
      return AuthFailure.wrongCode;
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return AuthFailure.rateLimited;
    }
    if (message.contains('phone')) return AuthFailure.invalidPhone;
    return AuthFailure.unknown;
  }
}

/// Used when this build has no Supabase credentials.
///
/// Reports [AuthFailure.notConfigured] rather than pretending to work, so the
/// screen can say which key is missing instead of looking broken.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  @override
  bool get isSignedIn => false;

  @override
  String? get userId => null;

  @override
  Stream<bool> get signedInChanges => const Stream<bool>.empty();

  @override
  Future<AuthFailure?> sendCode(TzPhone phone) async =>
      AuthFailure.notConfigured;

  @override
  Future<AuthFailure?> verifyCode(TzPhone phone, String code) async =>
      AuthFailure.notConfigured;

  @override
  Future<void> signOut() async {}
}
