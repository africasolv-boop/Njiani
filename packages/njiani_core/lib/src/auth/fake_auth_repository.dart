import 'dart:async';

import 'auth_failure.dart';
import 'auth_repository.dart';
import 'tz_phone.dart';

/// An in-memory [AuthRepository] for tests and for walking the app without
/// spending money on SMS.
///
/// Lives in `lib/`, not `test/`, so both apps' tests and a manual dev build
/// can use it. Nothing wires it in by default.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.code = '123456',
    this.sendFailure,
    this.verifyFailure,
    this.delay = Duration.zero,
  });

  /// The code this fake accepts.
  final String code;

  /// Forced failure for [sendCode], for exercising an error state.
  AuthFailure? sendFailure;

  /// Provider detail attached to a forced failure.
  String? failureDetail;

  /// Forced failure for [verifyCode].
  AuthFailure? verifyFailure;

  /// Artificial latency, for seeing the loading state.
  final Duration delay;

  /// Numbers that have been sent a code, in order.
  final List<TzPhone> sent = [];

  /// Codes that have been submitted, in order.
  final List<String> attempted = [];

  final _signedIn = StreamController<bool>.broadcast();
  bool _isSignedIn = false;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  String? get userId => _isSignedIn ? 'fake-user' : null;

  @override
  Stream<bool> get signedInChanges => _signedIn.stream;

  @override
  Future<AuthError?> sendCode(TzPhone phone) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (sendFailure != null) {
      return AuthError(sendFailure!, detail: failureDetail);
    }
    sent.add(phone);
    return null;
  }

  @override
  Future<AuthError?> verifyCode(TzPhone phone, String submitted) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    attempted.add(submitted);
    if (verifyFailure != null) {
      return AuthError(verifyFailure!, detail: failureDetail);
    }
    if (submitted != code) return const AuthError(AuthFailure.wrongCode);
    _isSignedIn = true;
    _signedIn.add(true);
    return null;
  }

  @override
  Future<void> signOut() async {
    _isSignedIn = false;
    _signedIn.add(false);
  }

  /// Releases the broadcast controller.
  void dispose() => _signedIn.close();
}
