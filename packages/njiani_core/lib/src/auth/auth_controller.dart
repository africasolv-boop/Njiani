import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_client.dart';
import 'auth_failure.dart';
import 'auth_repository.dart';
import 'tz_phone.dart';

/// How long before the code can be sent again.
///
/// Every send costs real money, so the countdown is not decoration. The server
/// enforces its own limit; this stops the obvious double-tap reaching it.
const Duration kResendWindow = Duration(seconds: 60);

/// How many digits the code has.
///
/// SIX, not the four drawn in the design project. Supabase Auth will not issue
/// an SMS code shorter than six digits -- its configurable range is 6 to 10 --
/// so four boxes could never be filled by a code it actually sent.
///
/// The security side of that constraint is also the right way round: an SMS
/// code is the only authentication factor in this app, and six digits is a
/// million combinations against four digits' ten thousand.
///
/// `NjOtpField` takes its length from here, so changing this one value moves
/// the whole screen.
const int kOtpLength = 6;

/// Where the user is in signing in.
enum AuthStep {
  /// Entering a phone number.
  phone,

  /// A code has been sent; entering it.
  code,

  /// Signed in.
  signedIn,
}

/// The sign-in screen's state.
class AuthState {
  const AuthState({
    this.step = AuthStep.phone,
    this.phone,
    this.busy = false,
    this.failure,
    this.codeSentAt,
  });

  /// Which screen should be showing.
  final AuthStep step;

  /// The number a code was sent to, once there is one.
  final TzPhone? phone;

  /// A request is in flight. Separate from [failure] so a button can show a
  /// spinner without the screen looking broken.
  final bool busy;

  /// Why the last attempt failed, if it did.
  final AuthFailure? failure;

  /// When the last code was sent, for the resend countdown.
  final DateTime? codeSentAt;

  /// Seconds left before a resend is allowed, given [now].
  int resendIn(DateTime now) {
    final sentAt = codeSentAt;
    if (sentAt == null) return 0;
    final remaining = kResendWindow - now.difference(sentAt);
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  AuthState copyWith({
    AuthStep? step,
    TzPhone? phone,
    bool? busy,
    AuthFailure? failure,
    DateTime? codeSentAt,
    bool clearFailure = false,
  }) =>
      AuthState(
        step: step ?? this.step,
        phone: phone ?? this.phone,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        codeSentAt: codeSentAt ?? this.codeSentAt,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.step == step &&
      other.phone == phone &&
      other.busy == busy &&
      other.failure == failure &&
      other.codeSentAt == codeSentAt;

  @override
  int get hashCode => Object.hash(step, phone, busy, failure, codeSentAt);
}

/// The current time.
///
/// Injected rather than calling [DateTime.now] directly so anything with a
/// countdown or an expiry can be tested without waiting for it. The request
/// window at C9 and the trip ETA at C11 need the same seam.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Supplies the [AuthRepository].
///
/// Defaults to the unconfigured one, so a build without credentials says so
/// rather than crashing on a null client.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null
      ? const UnconfiguredAuthRepository()
      : SupabaseAuthRepository(client);
});

/// Drives the phone and code screens.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);

    // Keep in step with the session: a token that expires or a sign-out
    // elsewhere must move the router, not leave a stale screen.
    final subscription = repository.signedInChanges.listen((signedIn) {
      state = signedIn
          ? state.copyWith(step: AuthStep.signedIn, clearFailure: true)
          : const AuthState();
    });
    ref.onDispose(subscription.cancel);

    return repository.isSignedIn
        ? const AuthState(step: AuthStep.signedIn)
        : const AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  DateTime get _now => ref.read(clockProvider)();

  /// Clears any error so the field stops looking wrong as soon as the user
  /// starts fixing it.
  void clearFailure() {
    if (state.failure != null) state = state.copyWith(clearFailure: true);
  }

  /// Sends a code to [raw], whatever form it was typed in.
  ///
  /// The number is never cleared on failure. Retyping a phone number on a
  /// moving bajaj is the worst thing this app could ask for, so the value
  /// stays and only the message changes.
  Future<void> sendCode(String raw) async {
    if (state.busy) return; // debounce: a second tap must not cost a second SMS

    final phone = TzPhone.tryParse(raw);
    if (phone == null) {
      state = state.copyWith(failure: AuthFailure.invalidPhone);
      return;
    }

    // Sending to the same number again inside the window is a resend, and a
    // resend costs another SMS. Go straight to the code screen instead: the
    // one already in flight is still valid.
    if (phone == state.phone && state.resendIn(_now) > 0) {
      state = state.copyWith(step: AuthStep.code, clearFailure: true);
      return;
    }

    state = state.copyWith(busy: true, clearFailure: true, phone: phone);
    final failure = await _repository.sendCode(phone);

    state = failure == null
        ? state.copyWith(
            step: AuthStep.code,
            busy: false,
            codeSentAt: _now,
            clearFailure: true,
          )
        : state.copyWith(busy: false, failure: failure);
  }

  /// Sends the code again to the number already captured.
  Future<void> resendCode() async {
    final phone = state.phone;
    if (phone == null || state.busy) return;
    if (state.resendIn(_now) > 0) return;

    state = state.copyWith(busy: true, clearFailure: true);
    final failure = await _repository.sendCode(phone);
    state = failure == null
        ? state.copyWith(busy: false, codeSentAt: _now, clearFailure: true)
        : state.copyWith(busy: false, failure: failure);
  }

  /// Exchanges [code] for a session.
  Future<void> verifyCode(String code) async {
    final phone = state.phone;
    if (phone == null || state.busy) return;
    if (code.length != kOtpLength) return;

    state = state.copyWith(busy: true, clearFailure: true);
    final failure = await _repository.verifyCode(phone, code);

    if (failure == null) {
      state = state.copyWith(
        step: AuthStep.signedIn,
        busy: false,
        clearFailure: true,
      );
    } else {
      state = state.copyWith(busy: false, failure: failure);
    }
  }

  /// Goes back to the phone screen, keeping the number so it does not have to
  /// be retyped.
  void editPhone() {
    state = state.copyWith(step: AuthStep.phone, clearFailure: true);
  }

  /// Signs out and returns to the start.
  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }
}

/// The sign-in state.
final authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
